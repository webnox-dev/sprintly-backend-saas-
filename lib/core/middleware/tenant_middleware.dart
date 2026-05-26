import 'dart:async';
import 'package:shelf/shelf.dart';


/// Zone key for organization ID
const Symbol organizationIdKey = #organizationId;

/// Middleware to manage multi-tenancy context
/// Extracts organizationId from request context and puts it into a Zone
Middleware tenantMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      final organizationId = request.context['organizationId'] as String?;

      if (organizationId != null) {
        return runZoned(
          () => handler(request),
          zoneValues: {organizationIdKey: organizationId},
        );
      }

      // For public endpoints or if not authenticated, proceed without tenant context
      return handler(request);
    };
  };
}

/// Helper to get current organization ID from Zone
String? getCurrentOrganizationId() {
  return Zone.current[organizationIdKey] as String?;
}
