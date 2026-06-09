import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../data/repositories/organization_repository.dart';
import '../data/database/connection.dart';
import '../core/middleware/tenant_middleware.dart';

class BillingRoutes {
  final Router _router = Router();
  final OrganizationRepository _orgRepository = OrganizationRepository();

  Router get router {
    _router.get('/plans', _getAvailablePlans);
    
    // Protected routes requiring organization context
    final protectedRouter = Router();
    protectedRouter.get('/usage', _getOrganizationUsage);
    protectedRouter.post('/create-order', _createRazorpayOrder);
    protectedRouter.post('/verify-payment', _verifyRazorpayPayment);

    _router.mount('/', Pipeline().addMiddleware(tenantMiddleware()).addHandler(protectedRouter.call));

    return _router;
  }

  /// Get all available subscription plans
  Future<Response> _getAvailablePlans(Request request) async {
    try {
      final plans = await _orgRepository.getAllPlans();
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': plans,
        }, toEncodable: (item) {
          if (item is DateTime) {
            return item.toIso8601String();
          }
          return item;
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to fetch plans: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Get current organization usage and limits
  Future<Response> _getOrganizationUsage(Request request) async {
    try {
      final orgId = getCurrentOrganizationId();
      if (orgId == null || orgId.isEmpty) {
        return Response(401, body: jsonEncode({'success': false, 'message': 'Organization context required'}));
      }

      final limits = await _orgRepository.getPlanLimits(orgId);
      if (limits == null) {
        return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Failed to fetch plan limits'}));
      }

      // Fetch the actual usage from the database
      final usageRow = await DatabaseConnection.queryOne('''
        SELECT 
          (SELECT COUNT(*)::int FROM employees WHERE organization_id = @orgId::uuid AND status = 1) as employee_count,
          (SELECT COUNT(*)::int FROM projects WHERE organization_id = @orgId::uuid) as project_count,
          (SELECT COALESCE(SUM(bytes_used), 0)::bigint FROM org_file_uploads WHERE organization_id = @orgId::uuid) as total_storage_bytes
      ''', values: {'orgId': orgId});
      
      return Response.ok(
        jsonEncode({
          'success': true,
          'data': {
            'limits': limits,
            'usage': usageRow ?? {
              'employee_count': 0,
              'project_count': 0,
              'total_storage_bytes': 0,
            }
          },
        }),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to fetch usage: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Create a Razorpay Order
  Future<Response> _createRazorpayOrder(Request request) async {
    try {
      final orgId = getCurrentOrganizationId();
      if (orgId == null || orgId.isEmpty) {
        return Response(401, body: jsonEncode({'success': false, 'message': 'Organization context required'}));
      }

      final payload = await request.readAsString();
      if (payload.isEmpty) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Request body cannot be empty'}));
      }

      final data = jsonDecode(payload);
      final String? planId = data['plan_id'];

      if (planId == null) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'plan_id is required'}));
      }

      // Fetch the plan details to get the price
      final plan = await _orgRepository.getPlanById(planId);
      if (plan == null) {
        return Response(404, body: jsonEncode({'success': false, 'message': 'Plan not found'}));
      }

      final priceString = plan['price']?.toString() ?? '0';
      final double price = double.tryParse(priceString) ?? 0.0;
      
      if (price <= 0) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Invalid plan price for payment'}));
      }

      // Razorpay expects amount in paise (multiply by 100)
      final amountInPaise = (price * 100).toInt();

      final razorpayKeyId = AppConfig.razorpayKeyId;
      final razorpayKeySecret = AppConfig.razorpayKeySecret;

      if (razorpayKeyId.isEmpty || razorpayKeySecret.isEmpty) {
        return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Razorpay keys not configured'}));
      }

      final authBytes = utf8.encode('$razorpayKeyId:$razorpayKeySecret');
      final base64Auth = base64.encode(authBytes);

      // Create order via Razorpay API
      final response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Authorization': 'Basic $base64Auth',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amountInPaise,
          'currency': 'INR',
          'receipt': 'org_${orgId.replaceAll('-', '')}',
          'notes': {
            'org_id': orgId,
            'plan_id': planId,
          }
        }),
      );

      final razorpayData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'data': {
              ...razorpayData,
              'key_id': razorpayKeyId,
            },
          }),
          headers: {'content-type': 'application/json'},
        );
      } else {
        return Response(response.statusCode, body: jsonEncode({
          'success': false,
          'message': 'Failed to create Razorpay order',
          'error': razorpayData
        }));
      }

    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to process order creation: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  /// Verify Razorpay Payment Signature and Upgrade Plan
  Future<Response> _verifyRazorpayPayment(Request request) async {
    try {
      final orgId = getCurrentOrganizationId();
      if (orgId == null || orgId.isEmpty) {
        return Response(401, body: jsonEncode({'success': false, 'message': 'Organization context required'}));
      }

      final payload = await request.readAsString();
      if (payload.isEmpty) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Request body cannot be empty'}));
      }

      final data = jsonDecode(payload);
      final String? razorpayPaymentId = data['razorpay_payment_id'];
      final String? razorpayOrderId = data['razorpay_order_id'];
      final String? razorpaySignature = data['razorpay_signature'];
      final String? planId = data['plan_id']; // The plan the user just paid for

      if (razorpayPaymentId == null || razorpayOrderId == null || razorpaySignature == null || planId == null) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Missing payment verification details'}));
      }

      final razorpayKeySecret = AppConfig.razorpayKeySecret;
      if (razorpayKeySecret.isEmpty) {
        return Response.internalServerError(body: jsonEncode({'success': false, 'message': 'Razorpay secret not configured'}));
      }

      // Verify SHA256 Signature
      final generatedSignature = _generateHmacSha256(razorpayKeySecret, '$razorpayOrderId|$razorpayPaymentId');
      
      if (generatedSignature != razorpaySignature) {
        return Response(400, body: jsonEncode({'success': false, 'message': 'Invalid payment signature'}));
      }

      // If signature matches, update the organization's plan_id and subscription dates
      final now = DateTime.now().toUtc();
      final endsAt = now.add(const Duration(days: 30));
      
      await _orgRepository.update(orgId, {
        'plan_id': planId,
        'status': 'active',
        'subscription_starts_at': now.toIso8601String(),
        'subscription_ends_at': endsAt.toIso8601String(),
      });

      return Response.ok(
        jsonEncode({
          'success': true,
          'message': 'Payment verified and plan upgraded successfully',
        }),
        headers: {'content-type': 'application/json'},
      );

    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({
          'success': false,
          'message': 'Failed to verify payment: $e',
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  String _generateHmacSha256(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }
}
