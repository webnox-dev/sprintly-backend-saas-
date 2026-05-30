import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../../data/repositories/organization_repository.dart';
import 'tenant_middleware.dart';

/// Middleware to guard routes based on SaaS plan features.
class FeatureMiddleware {
  static final OrganizationRepository _orgRepository = OrganizationRepository();

  /// Creates a middleware that checks if the current organization has the required feature.
  /// If not, it returns a 403 Forbidden response prompting for an upgrade.
  static Middleware requireFeature(String featureName) {
    return (Handler innerHandler) {
      return (Request request) async {
        final orgId = getCurrentOrganizationId();
        
        // If there's no organization context, we can't enforce plan features.
        // The tenant middleware should have already validated the tenant, but
        // for super admin routes, there might not be an org context.
        if (orgId == null || orgId.isEmpty) {
          return innerHandler(request);
        }

        try {
          final features = await _orgRepository.getPlanFeatures(orgId);
          
          // Check if the required feature is present and enabled
          // features is a Map<String, dynamic> like {"Salary": true, "Team Sync": false}
          final hasFeature = features?[featureName] == true;

          if (!hasFeature) {
            return Response(
              403,
              body: jsonEncode({
                'success': false,
                'message': 'Access denied: The feature "$featureName" is not available on your current plan. Please upgrade to use this feature.',
                'error': {
                  'code': 'FEATURE_NOT_AVAILABLE',
                  'message': 'Upgrade required'
                }
              }),
              headers: {'content-type': 'application/json'},
            );
          }

          // Feature is enabled, proceed to the inner handler
          return innerHandler(request);
        } catch (e) {
          // Log error and optionally deny access, but for now we might want to 
          // allow if DB fails, or fail closed. Failing closed is safer.
          return Response(
            500,
            body: jsonEncode({
              'success': false,
              'message': 'Failed to verify feature access due to an internal error.',
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      };
    };
  }
}
