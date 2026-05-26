import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:webnox_sprintly_admin_backend/config/app_config.dart';
import 'package:webnox_sprintly_admin_backend/core/middleware/cors_middleware.dart';
import 'package:webnox_sprintly_admin_backend/core/middleware/error_handler.dart';
import 'package:webnox_sprintly_admin_backend/core/middleware/logging_middleware.dart';
import 'package:webnox_sprintly_admin_backend/core/middleware/auth_middleware.dart';
import 'package:webnox_sprintly_admin_backend/core/middleware/tenant_middleware.dart';
import 'package:webnox_sprintly_admin_backend/routes/router.dart';
import 'package:webnox_sprintly_admin_backend/data/database/connection.dart';
import 'package:webnox_sprintly_admin_backend/data/database/migration_service.dart';
import 'package:webnox_sprintly_admin_backend/core/utils/logger.dart';
import 'package:webnox_sprintly_admin_backend/services/firebase_notification_service.dart';
import 'package:webnox_sprintly_admin_backend/services/celebration_scheduler_service.dart';
import 'package:webnox_sprintly_admin_backend/services/meeting_reminder_service.dart';
import 'package:webnox_sprintly_admin_backend/services/google_meet_service.dart';

void main(List<String> args) async {
  final logger = AppLogger('Server');

  try {
    // Initialize environment configuration from .env file
    logger.info('Loading environment configuration...');
    AppConfig.initialize();

    // Run migrations first to ensure database exists and tables are created
    logger.info('Running database migrations...');
    await MigrationService.runMigrations();
    logger.info('Database migrations completed');

    // Now get the database connection
    logger.info('Initializing database connection...');
    await DatabaseConnection.getConnection();
    logger.info('Database connected successfully');

    // Initialize Firebase Cloud Messaging service
    logger.info('Initializing Firebase notification service...');
    await FirebaseNotificationService.initialize();
    logger.info('Firebase notification service initialized');

    // Start system scheduler
    logger.info('Starting system scheduler...');
    CelebrationSchedulerService.startScheduler();
    logger.info('System scheduler started');

    // Start meeting reminder scheduler (every 1 minute)
    logger.info('Starting meeting reminder scheduler...');
    MeetingReminderService.startScheduler();
    logger.info('Meeting reminder scheduler started');

    // Initialize Google Meet service (optional — works without it)
    logger.info('Initializing Google Meet service...');
    await GoogleMeetService.initialize();
    if (GoogleMeetService.isAvailable) {
      logger.info('Google Meet service initialized — real Meet links enabled');
    } else {
      logger.info('Google Meet service not configured — using fallback links');
    }

    // Initialize router
    final appRouter = AppRouter();
    final router = appRouter.router;

    // Configure middleware pipeline
    final handler = Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(corsHandler)
        .addMiddleware(loggingMiddleware())
        .addMiddleware(authMiddleware()) // Add authentication middleware
        .addMiddleware(tenantMiddleware()) // Add multi-tenancy context middleware
        .addMiddleware(errorHandler())
        .addHandler(router.call);

    // Start server
    final ip = InternetAddress.anyIPv4;
    final port = AppConfig.serverPort;

    logger.info('Starting server on $ip:$port...');
    final server = await serve(handler, ip, port);

    logger.info(
      '✅ Server listening on http://${server.address.host}:${server.port}',
    );
    logger.info('Environment: ${AppConfig.environment}');
    logger.info(
      'Health check: http://${server.address.host}:${server.port}/health',
    );
    logger.info(
      'API base URL: http://${server.address.host}:${server.port}/api',
    );

    // Handle shutdown gracefully
    ProcessSignal.sigint.watch().listen((signal) {
      logger.info('Received shutdown signal, closing...');
      MeetingReminderService.stopScheduler();
      GoogleMeetService.dispose();
      server.close();
      DatabaseConnection.close();
      exit(0);
    });
  } catch (e, stackTrace) {
    logger.error('Failed to start server: $e', e, stackTrace);
    exit(1);
  }
}
