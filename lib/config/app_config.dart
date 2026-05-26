import 'dart:io';
import 'package:dotenv/dotenv.dart';

/// Application configuration loaded from .env file
class AppConfig {
  static DotEnv? _dotenv;
  static bool _initialized = false;

  /// Initialize the environment configuration
  /// Should be called once at application startup
  static void initialize() {
    if (_initialized) return;

    _dotenv = DotEnv(includePlatformEnvironment: true);

    // Try to load .env file from current and parent directory
    final envFile = File('.env');
    final parentEnvFile = File('../.env');

    if (envFile.existsSync()) {
      _dotenv!.load(['.env']);
      print('✅ Loaded environment configuration from .env file');
    } else if (parentEnvFile.existsSync()) {
      _dotenv!.load(['../.env']);
      print('✅ Loaded environment configuration from parent .env file');
    } else {
      print('⚠️ No .env file found');
    }

    _initialized = true;
  }

  /// Get environment variable with fallback
  static String _getEnv(String key, String defaultValue, {bool critical = false}) {
    // Ensure initialized
    if (!_initialized) initialize();

    // Try dotenv first, then platform environment
    final value = _dotenv?[key] ?? Platform.environment[key];
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
    
    // If critical and no value found (and no non-placeholder default), throw error
    if (critical && (defaultValue.isEmpty || defaultValue.contains('your-secret-key') || defaultValue.contains('placeholder'))) {
      throw Exception('CRITICAL CONFIGURATION MISSING: $key is not set in .env or environment variables.');
    }
    
    return defaultValue;
  }

  // ---------------------------------------------------------------------------
  // SERVER CONFIGURATION
  // ---------------------------------------------------------------------------
  static int get serverPort => int.tryParse(_getEnv('PORT', '8080')) ?? 8080;

  static String get environment => _getEnv('ENVIRONMENT', 'development');

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  // ---------------------------------------------------------------------------
  // DATABASE CONFIGURATION
  // ---------------------------------------------------------------------------
  static String get databaseUrl {
    if (isProduction) {
      return databaseUrlLive;
    }
    return databaseUrlLocal;
  }

  static String get databaseUrlLocal => _getEnv(
    'DATABASE_URL_LOCAL',
    'postgres://postgres:1234@localhost:5432/webnox_sprintly',
  );

  static String get databaseUrlLive => _getEnv(
    'DATABASE_URL_LIVE',
    'postgres://postgres:1234@192.168.0.32:5435/webnox_sprintly',
  );

  // ---------------------------------------------------------------------------
  // JWT AUTHENTICATION
  // ---------------------------------------------------------------------------
  static String get jwtSecret =>
      _getEnv('JWT_SECRET', '', critical: true);

  static int get jwtExpirationHours =>
      int.tryParse(_getEnv('JWT_EXPIRATION_HOURS', '8')) ?? 8;

  // ---------------------------------------------------------------------------
  // SECURITY CONFIGURATION
  // ---------------------------------------------------------------------------
  static List<String> get allowedOrigins {
    final origins = _getEnv('ALLOWED_ORIGINS', '');
    if (origins.isEmpty) {
      return isProduction ? [] : ['*']; // Default to strict in prod, open in dev if not set
    }
    return origins.split(',').map((o) => o.trim()).toList();
  }

  // ---------------------------------------------------------------------------
  // CLOUDINARY CONFIGURATION
  // ---------------------------------------------------------------------------
  static String get cloudinaryCloudName =>
      _getEnv('CLOUDINARY_CLOUD_NAME', '');

  static String get cloudinaryApiKey =>
      _getEnv('CLOUDINARY_API_KEY', '');

  static String get cloudinaryApiSecret =>
      _getEnv('CLOUDINARY_API_SECRET', '');

  static String get cloudinaryUploadPreset =>
      _getEnv('CLOUDINARY_UPLOAD_PRESET', 'ml_default');

  static String get cloudinaryRawUploadPreset =>
      _getEnv('CLOUDINARY_RAW_UPLOAD_PRESET', 'ml_default');

  static String get cloudinaryBaseUrl => _getEnv(
    'CLOUDINARY_BASE_URL',
    'https://api.cloudinary.com/v1_1/${cloudinaryCloudName}/image/upload',
  );

  // ---------------------------------------------------------------------------
  // N8N WEBHOOK CONFIGURATION
  // ---------------------------------------------------------------------------
  static String get n8nBaseUrl =>
      _getEnv('N8N_BASE_URL', 'https://automation.webnoxdigital.com');

  static String get emailWebhookUrl => _getEnv(
    'EMAIL_WEBHOOK_URL',
    'https://automation.webnoxdigital.com/webhook/81eecf3f-081e-44fd-88dc-bc42ccb0c5fe',
  );

  static String get emailWebhookTestUrl => _getEnv(
    'EMAIL_WEBHOOK_TEST_URL',
    'https://automation.webnoxdigital.com/webhook-test/81eecf3f-081e-44fd-88dc-bc42ccb0c5fe',
  );

  // ---------------------------------------------------------------------------
  // LLM (AI ASSISTANT) CONFIGURATION
  // ---------------------------------------------------------------------------
  /// Active LLM provider: 'gemini', 'openai', 'openrouter', or 'deepseek'
  static String get activeLlmProvider =>
      _getEnv('ACTIVE_LLM_PROVIDER', 'gemini');

  static bool get useGemini => activeLlmProvider == 'gemini';
  static bool get useOpenAI => activeLlmProvider == 'openai';
  static bool get useOpenRouter => activeLlmProvider == 'openrouter';
  static bool get useDeepSeek => activeLlmProvider == 'deepseek';

  /// Gemini Configuration
  static String get geminiApiKey => _getEnv('GEMINI_API_KEY', '');

  static String get geminiModel => _getEnv('GEMINI_MODEL', 'gemini-2.0-flash');

  /// OpenAI Configuration
  static String get openaiApiKey => _getEnv('OPENAI_API_KEY', '');

  static String get openaiModel => _getEnv('OPENAI_MODEL', 'gpt-4.1-mini');

  /// OpenRouter Configuration
  static String get openrouterApiKey => _getEnv('OPENROUTER_API_KEY', '');

  static String get openrouterModel =>
      _getEnv('OPENROUTER_MODEL', 'google/gemini-2.0-flash-001');

  /// DeepSeek Configuration
  static String get deepseekApiKey => _getEnv('DEEPSEEK_API_KEY', '');

  static String get deepseekModel => _getEnv('DEEPSEEK_MODEL', 'deepseek-chat');

  /// Get active API key based on provider
  static String get llmApiKey {
    if (useGemini) return geminiApiKey;
    if (useOpenRouter) return openrouterApiKey;
    if (useDeepSeek) return deepseekApiKey;
    return openaiApiKey;
  }

  /// Get active model based on provider
  static String get llmModel {
    if (useGemini) return geminiModel;
    if (useOpenRouter) return openrouterModel;
    if (useDeepSeek) return deepseekModel;
    return openaiModel;
  }

  // ---------------------------------------------------------------------------
  // GOOGLE CALENDAR API CONFIGURATION
  // ---------------------------------------------------------------------------
  static String get googleServiceAccountPath =>
      _getEnv('GOOGLE_SERVICE_ACCOUNT_PATH', 'google-service-account.json');

  static String get googleCalendarId =>
      _getEnv('GOOGLE_CALENDAR_ID', 'primary');

  // ---------------------------------------------------------------------------
  // INTERNAL SECRET CONFIGURATION
  // ---------------------------------------------------------------------------
  /// Hardcoded secret key for specific internal/external APIs
  static String get internalSecretKey => _getEnv('INTERNAL_SECRET_KEY', 'SprintlyInternal@2024');

  // ---------------------------------------------------------------------------
  // SUPER ADMIN CONFIGURATION (Platform-level)
  // ---------------------------------------------------------------------------
  /// Separate JWT secret for super admin tokens — MUST differ from jwtSecret
  static String get superAdminJwtSecret =>
      _getEnv('SUPER_ADMIN_JWT_SECRET', 'sprintly-super-admin-secret-change-me-2026');

  /// Super admin JWT expiration in hours (shorter than regular users for security)
  static int get superAdminJwtExpirationHours =>
      int.tryParse(_getEnv('SUPER_ADMIN_JWT_EXPIRATION_HOURS', '4')) ?? 4;
}
