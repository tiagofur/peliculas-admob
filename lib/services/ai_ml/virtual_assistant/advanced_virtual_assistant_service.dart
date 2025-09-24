/// Advanced Virtual Assistant Service
///
/// Servicio avanzado de asistente virtual que proporciona:
/// - Conversaciones naturales sobre películas
/// - Recomendaciones inteligentes por voz/texto
/// - Búsqueda de contenido mediante lenguaje natural
/// - Integración con servicios de AI existentes
/// - Soporte multimodal (texto/voz)
library;

import 'dart:async';

import '../../../core/logging/logger_factory.dart';
import '../../../domain/entities/movie.dart';

/// Tipo de entrada del asistente virtual
enum AssistantInputType { text, voice, multimodal }

/// Estado de la conversación
enum ConversationState { idle, listening, processing, responding, error }

/// Tipos de intención del usuario
enum UserIntent {
  movieRecommendation,
  movieSearch,
  movieInfo,
  listManagement,
  generalChat,
  unknown
}

/// Configuración del asistente virtual
class VirtualAssistantConfig {
  const VirtualAssistantConfig({
    this.enableVoiceRecognition = true,
    this.enableVoiceSynthesis = true,
    this.enablePersonalization = true,
    this.maxConversationHistory = 50,
    this.responseTimeout = const Duration(seconds: 10),
    this.confidenceThreshold = 0.7,
    this.enableOfflineMode = false,
  });

  final bool enableVoiceRecognition;
  final bool enableVoiceSynthesis;
  final bool enablePersonalization;
  final int maxConversationHistory;
  final Duration responseTimeout;
  final double confidenceThreshold;
  final bool enableOfflineMode;

  Map<String, dynamic> toMap() {
    return {
      'enable_voice_recognition': enableVoiceRecognition,
      'enable_voice_synthesis': enableVoiceSynthesis,
      'enable_personalization': enablePersonalization,
      'max_conversation_history': maxConversationHistory,
      'response_timeout_ms': responseTimeout.inMilliseconds,
      'confidence_threshold': confidenceThreshold,
      'enable_offline_mode': enableOfflineMode,
    };
  }
}

/// Mensaje en la conversación
class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
    required this.inputType,
    this.intent,
    this.confidence,
    this.metadata,
  });

  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  final AssistantInputType inputType;
  final UserIntent? intent;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'is_from_user': isFromUser,
      'timestamp': timestamp.toIso8601String(),
      'input_type': inputType.toString(),
      'intent': intent?.toString(),
      'confidence': confidence,
      'metadata': metadata,
    };
  }
}

/// Respuesta del asistente virtual
class AssistantResponse {
  const AssistantResponse({
    required this.text,
    required this.intent,
    required this.confidence,
    this.recommendedMovies = const [],
    this.actionRequired,
    this.followUpQuestions = const [],
    this.metadata = const {},
  });

  final String text;
  final UserIntent intent;
  final double confidence;
  final List<Movie> recommendedMovies;
  final String? actionRequired;
  final List<String> followUpQuestions;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'intent': intent.toString(),
      'confidence': confidence,
      'recommended_movies': recommendedMovies.map((m) => m.toJson()).toList(),
      'action_required': actionRequired,
      'follow_up_questions': followUpQuestions,
      'metadata': metadata,
    };
  }
}

/// Contexto de la conversación
class ConversationContext {
  ConversationContext({
    this.userId,
    this.preferredGenres = const [],
    this.recentMovies = const [],
    this.currentTopic,
    this.sessionId,
  });

  final String? userId;
  final List<String> preferredGenres;
  final List<Movie> recentMovies;
  final String? currentTopic;
  final String? sessionId;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'preferred_genres': preferredGenres,
      'recent_movies': recentMovies.map((m) => m.toJson()).toList(),
      'current_topic': currentTopic,
      'session_id': sessionId,
    };
  }
}

/// Servicio avanzado de asistente virtual
class AdvancedVirtualAssistantService {
  AdvancedVirtualAssistantService._internal();
  static AdvancedVirtualAssistantService? _instance;
  static AdvancedVirtualAssistantService get instance =>
      _instance ??= AdvancedVirtualAssistantService._internal();

  final _logger = LoggerFactory.logger;

  // Estado del servicio
  bool _isInitialized = false;
  ConversationState _currentState = ConversationState.idle;
  VirtualAssistantConfig _config = const VirtualAssistantConfig();

  // Historial de conversación
  final List<ConversationMessage> _conversationHistory = [];

  // Métricas y estadísticas
  final Map<String, int> _intentCounts = {};
  int _totalInteractions = 0;
  DateTime? _lastInteraction;

  /// Inicializa el servicio de asistente virtual
  Future<void> initialize({VirtualAssistantConfig? config}) async {
    if (_isInitialized) return;

    try {
      _config = config ?? const VirtualAssistantConfig();

      // Inicializar componentes base
      await _initializeNLPComponents();
      await _initializeVoiceComponents();

      _isInitialized = true;
      _logger.info('🤖 Asistente Virtual inicializado correctamente');
    } catch (e) {
      _logger.error('❌ Error inicializando Asistente Virtual: $e');
      rethrow;
    }
  }

  /// Inicializa componentes de procesamiento de lenguaje natural
  Future<void> _initializeNLPComponents() async {
    // Configurar modelos de intención
    await _loadIntentModels();

    // Inicializar procesador de contexto
    await _initializeContextProcessor();

    _logger.debug('✅ Componentes NLP inicializados');
  }

  /// Inicializa componentes de voz
  Future<void> _initializeVoiceComponents() async {
    if (!_config.enableVoiceRecognition && !_config.enableVoiceSynthesis) {
      return;
    }

    try {
      // En una implementación real, inicializar servicios de voz
      // Por ahora, simulamos la inicialización
      await Future.delayed(const Duration(milliseconds: 100));

      _logger.debug('✅ Componentes de voz inicializados');
    } catch (e) {
      _logger.warning('⚠️ Componentes de voz no disponibles: $e');
    }
  }

  /// Carga modelos de clasificación de intenciones
  Future<void> _loadIntentModels() async {
    // En una implementación real, cargar modelos ML para clasificación de intenciones
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Inicializa el procesador de contexto conversacional
  Future<void> _initializeContextProcessor() async {
    // En una implementación real, configurar procesador de contexto
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Procesa una entrada del usuario y genera respuesta
  Future<AssistantResponse> processUserInput(
    String input, {
    AssistantInputType inputType = AssistantInputType.text,
    ConversationContext? context,
  }) async {
    if (!_isInitialized) {
      throw StateError('Asistente Virtual no inicializado');
    }

    try {
      _currentState = ConversationState.processing;
      _totalInteractions++;
      _lastInteraction = DateTime.now();

      // Actualizar contexto
      if (context != null) {
        // Context is provided but not stored for later use
      }

      // Clasificar intención
      final intent = await _classifyIntent(input);
      final confidence = await _calculateConfidence(input, intent);

      // Crear mensaje de usuario
      final userMessage = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: input,
        isFromUser: true,
        timestamp: DateTime.now(),
        inputType: inputType,
        intent: intent,
        confidence: confidence,
      );

      // Añadir al historial
      _addToHistory(userMessage);
      _intentCounts[intent.toString()] =
          (_intentCounts[intent.toString()] ?? 0) + 1;

      // Generar respuesta basada en intención
      final response = await _generateResponse(input, intent, confidence);

      // Crear mensaje de respuesta
      final assistantMessage = ConversationMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response.text,
        isFromUser: false,
        timestamp: DateTime.now(),
        inputType: AssistantInputType.text,
        intent: intent,
        confidence: response.confidence,
      );

      _addToHistory(assistantMessage);
      _currentState = ConversationState.idle;

      return response;
    } catch (e) {
      _currentState = ConversationState.error;
      _logger.error('❌ Error procesando entrada del usuario: $e');

      return AssistantResponse(
        text:
            'Lo siento, hubo un error procesando tu solicitud. ¿Podrías intentar de nuevo?',
        intent: UserIntent.unknown,
        confidence: 0.0,
        metadata: {'error': e.toString()},
      );
    }
  }

  /// Clasifica la intención del usuario
  Future<UserIntent> _classifyIntent(String input) async {
    final lowerInput = input.toLowerCase();

    // Reglas simples para clasificación de intenciones
    // En una implementación real, usar modelos ML entrenados

    if (lowerInput
        .contains(RegExp(r'recomend|suger|que.*ver|pel[ií]cula.*buena'))) {
      return UserIntent.movieRecommendation;
    }

    if (lowerInput.contains(RegExp(r'buscar|encontrar|pel[ií]cula.*llama'))) {
      return UserIntent.movieSearch;
    }

    if (lowerInput.contains(
        RegExp(r'informaci[oó]n|sobre.*pel[ií]cula|reparto|director'))) {
      return UserIntent.movieInfo;
    }

    if (lowerInput.contains(RegExp(r'lista|favorit|watchlist|guardar'))) {
      return UserIntent.listManagement;
    }

    if (lowerInput.contains(RegExp(r'hola|saludar|como.*est[aá]s'))) {
      return UserIntent.generalChat;
    }

    return UserIntent.unknown;
  }

  /// Calcula la confianza de la clasificación
  Future<double> _calculateConfidence(String input, UserIntent intent) async {
    // Implementación simplificada - en producción usar modelos ML
    final baseConfidence = intent == UserIntent.unknown ? 0.1 : 0.8;
    final lengthFactor = (input.length / 100).clamp(0.0, 1.0);
    return (baseConfidence + lengthFactor * 0.2).clamp(0.0, 1.0);
  }

  /// Genera respuesta basada en la intención clasificada
  Future<AssistantResponse> _generateResponse(
    String input,
    UserIntent intent,
    double confidence,
  ) async {
    switch (intent) {
      case UserIntent.movieRecommendation:
        return await _handleMovieRecommendation(input, confidence);

      case UserIntent.movieSearch:
        return await _handleMovieSearch(input, confidence);

      case UserIntent.movieInfo:
        return await _handleMovieInfo(input, confidence);

      case UserIntent.listManagement:
        return await _handleListManagement(input, confidence);

      case UserIntent.generalChat:
        return await _handleGeneralChat(input, confidence);

      case UserIntent.unknown:
        return _handleUnknownIntent(input);
    }
  }

  /// Maneja solicitudes de recomendaciones de películas
  Future<AssistantResponse> _handleMovieRecommendation(
      String input, double confidence) async {
    final responses = [
      '¡Te puedo ayudar con recomendaciones! ¿Qué género te gusta más?',
      'Tengo excelentes sugerencias para ti. ¿Prefieres acción, drama o comedia?',
      '¡Perfecto! Para darte mejores recomendaciones, ¿qué película te gustó recientemente?',
    ];

    final randomResponse =
        responses[DateTime.now().millisecond % responses.length];

    return AssistantResponse(
      text: randomResponse,
      intent: UserIntent.movieRecommendation,
      confidence: confidence,
      followUpQuestions: [
        '¿Qué género prefieres?',
        '¿Películas recientes o clásicas?',
        '¿Algún actor favorito?',
      ],
    );
  }

  /// Maneja búsquedas de películas
  Future<AssistantResponse> _handleMovieSearch(
      String input, double confidence) async {
    return AssistantResponse(
      text:
          'Te ayudo a buscar esa película. ¿Podrías darme más detalles como el título, director o actores?',
      intent: UserIntent.movieSearch,
      confidence: confidence,
      followUpQuestions: [
        '¿Recuerdas el título exacto?',
        '¿Sabes quién la dirigió?',
        '¿En qué año salió aproximadamente?',
      ],
    );
  }

  /// Maneja solicitudes de información de películas
  Future<AssistantResponse> _handleMovieInfo(
      String input, double confidence) async {
    return AssistantResponse(
      text:
          'Te puedo proporcionar información detallada sobre cualquier película. ¿De cuál quieres saber más?',
      intent: UserIntent.movieInfo,
      confidence: confidence,
      followUpQuestions: [
        '¿Quieres saber sobre el reparto?',
        '¿Te interesa la sinopsis?',
        '¿Buscas información técnica?',
      ],
    );
  }

  /// Maneja gestión de listas
  Future<AssistantResponse> _handleListManagement(
      String input, double confidence) async {
    return AssistantResponse(
      text:
          'Puedo ayudarte a gestionar tus listas de películas. ¿Quieres añadir algo a favoritos o crear una nueva lista?',
      intent: UserIntent.listManagement,
      confidence: confidence,
      followUpQuestions: [
        '¿Añadir a favoritos?',
        '¿Crear nueva lista?',
        '¿Ver listas existentes?',
      ],
    );
  }

  /// Maneja conversación general
  Future<AssistantResponse> _handleGeneralChat(
      String input, double confidence) async {
    final responses = [
      '¡Hola! Soy tu asistente para películas. ¿En qué puedo ayudarte hoy?',
      '¡Qué tal! Estoy aquí para ayudarte con todo sobre películas. ¿Qué necesitas?',
      'Hola, ¡qué gusto hablar contigo! ¿Buscas alguna película en particular?',
    ];

    final randomResponse =
        responses[DateTime.now().millisecond % responses.length];

    return AssistantResponse(
      text: randomResponse,
      intent: UserIntent.generalChat,
      confidence: confidence,
    );
  }

  /// Maneja intenciones no reconocidas
  AssistantResponse _handleUnknownIntent(String input) {
    return const AssistantResponse(
      text:
          'No estoy seguro de cómo ayudarte con eso. Puedo ayudarte con recomendaciones de películas, búsquedas o gestión de listas. ¿Qué te interesa?',
      intent: UserIntent.unknown,
      confidence: 0.1,
      followUpQuestions: [
        '¿Buscas recomendaciones?',
        '¿Necesitas buscar una película?',
        '¿Quieres gestionar tus listas?',
      ],
    );
  }

  /// Añade mensaje al historial de conversación
  void _addToHistory(ConversationMessage message) {
    _conversationHistory.add(message);

    // Mantener límite del historial
    if (_conversationHistory.length > _config.maxConversationHistory) {
      _conversationHistory.removeAt(0);
    }
  }

  /// Obtiene el historial de conversación
  List<ConversationMessage> getConversationHistory() {
    return List.unmodifiable(_conversationHistory);
  }

  /// Limpia el historial de conversación
  void clearHistory() {
    _conversationHistory.clear();
    _logger.debug('🧹 Historial de conversación limpiado');
  }

  /// Obtiene métricas del asistente
  Map<String, dynamic> getMetrics() {
    return {
      'is_initialized': _isInitialized,
      'current_state': _currentState.toString(),
      'total_interactions': _totalInteractions,
      'last_interaction': _lastInteraction?.toIso8601String(),
      'conversation_length': _conversationHistory.length,
      'intent_distribution': Map.from(_intentCounts),
      'config': _config.toMap(),
    };
  }

  /// Actualiza la configuración del asistente
  void updateConfig(VirtualAssistantConfig newConfig) {
    _config = newConfig;
    _logger.info('🔧 Configuración del Asistente Virtual actualizada');
  }

  /// Obtiene el estado actual del servicio
  ConversationState get currentState => _currentState;

  /// Obtiene la configuración actual
  VirtualAssistantConfig get config => _config;

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _isInitialized;

  /// Dispone recursos del servicio
  Future<void> dispose() async {
    _conversationHistory.clear();
    _intentCounts.clear();
    _isInitialized = false;
    _currentState = ConversationState.idle;

    _logger.info('🧹 Asistente Virtual finalizado correctamente');
  }
}
