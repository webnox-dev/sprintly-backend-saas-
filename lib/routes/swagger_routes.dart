import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:path/path.dart' as p;

class SwaggerRoutes {
  Router get router {
    final router = Router();

    // Serve the Swagger UI HTML
    router.get('/', _serveSwaggerUI);

    // Serve the Swagger YAML file
    router.get('/swagger.yaml', _serveSwaggerYaml);

    return router;
  }

  // Expose handlers so they can be mounted directly at exact paths
  Response uiHandler(Request request) => _serveSwaggerUI(request);
  Future<Response> yamlHandler(Request request) => _serveSwaggerYaml(request);

  Response _serveSwaggerUI(Request request) {
    // Determine the base path for swagger.yaml
    // If request path is /api/ or /api, we should use ./swagger.yaml or just swagger.yaml
    // If request path effectively ends in /, browser will look for ./swagger.yaml

    const htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="SwaggerUI" />
  <title>Sprintly Admin API Docs</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" />
  <style>
    body { margin: 0; padding: 0; }
  </style>
</head>
<body>
<div id="swagger-ui"></div>
<script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js" crossorigin></script>
<script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js" crossorigin></script>
<script>
  window.onload = () => {
    // Check if we are at root /api or /spi
    // Ideally we want to point to the sibling swagger.yaml
    const url = window.location.pathname.endsWith('/') ? 'swagger.yaml' : window.location.pathname + '/swagger.yaml';
    
    // Fallback: if we are at /api, try just appending swagger.yaml 
    // If we are at /api/, appending swagger.yaml works
    
    // Let's be smart: Try to detect where we are serving from
    let yamlUrl = 'swagger.yaml'; // Default relative path
    
    if (window.location.pathname === '/api' || window.location.pathname === '/api/') {
       yamlUrl = '/api/swagger.yaml';
    } else if (window.location.pathname === '/spi' || window.location.pathname === '/spi/') {
       yamlUrl = '/spi/swagger.yaml';
    }

    window.ui = SwaggerUIBundle({
      url: yamlUrl,
      dom_id: '#swagger-ui',
      deepLinking: true,
      presets: [
        SwaggerUIBundle.presets.apis,
        SwaggerUIStandalonePreset
      ],
      plugins: [
        SwaggerUIBundle.plugins.DownloadUrl
      ],
      layout: "StandaloneLayout",
    });
  };
</script>
</body>
</html>
    ''';

    return Response.ok(htmlContent, headers: {'content-type': 'text/html'});
  }

  Future<Response> _serveSwaggerYaml(Request request) async {
    try {
      final current = Directory.current;
      String yamlPath = 'lib/specs/swagger.yaml'; // Default

      if (await File(
        p.join(current.path, 'lib', 'specs', 'swagger.yaml'),
      ).exists()) {
        yamlPath = p.join(current.path, 'lib', 'specs', 'swagger.yaml');
      } else if (await File(
        p.join(
          current.path,
          'webnox_sprintly_backend',
          'lib',
          'specs',
          'swagger.yaml',
        ),
      ).exists()) {
        yamlPath = p.join(
          current.path,
          'webnox_sprintly_backend',
          'lib',
          'specs',
          'swagger.yaml',
        );
      }

      final file = File(yamlPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        return Response.ok(
          content,
          headers: {'content-type': 'application/yaml'},
        );
      } else {
        return Response.notFound('Swagger YAML not found');
      }
    } catch (e) {
      return Response.internalServerError(
        body: 'Error serving Swagger YAML: $e',
      );
    }
  }
}
