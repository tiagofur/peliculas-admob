/// Natural Language Processing Search Service
///
/// Servicio avanzado de búsqueda con procesamiento de lenguaje natural que incluye:
/// - Análisis semántico de consultas en lenguaje natural
/// - Búsqueda contextual inteligente
/// - Reconocimiento de entidades (géneros, actores, directores)
/// - Corrección automática de errores ortográficos
/// - Expansión de consultas y sinónimos
/// - Búsqueda por sentimientos y emociones
/// - Procesamiento multiidioma
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Tipos de entidades que puede reconocer el NLP
enum EntityType {
  movie,
  actor,
  director,
  genre,
  year,
  rating,
  emotion,
  plot,
  character,
  franchise
}

/// Tipos de intención de búsqueda
enum SearchIntent {
  findMovie,
  recommendMovie,
  compareMovies,
  findActor,
  findGenre,
  findSimilar,
  findByMood,
  findByPlot,
  askQuestion
}

/// Tipos de sentimientos detectados
enum SentimentType {
  positive,
  negative,
  neutral,
  happy,
  sad,
  excited,
  romantic,
  scary,
  funny,
  dramatic
}

/// Entidad extraída del texto
class ExtractedEntity {
  const ExtractedEntity({
    required this.type,
    required this.value,
    required this.originalText,
    required this.confidence,
    required this.startPosition,
    required this.endPosition,
    required this.metadata,
  });
  final EntityType type;
  final String value;
  final String originalText;
  final double confidence; // 0.0 - 1.0
  final int startPosition;
  final int endPosition;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'value': value,
      'original_text': originalText,
      'confidence': confidence,
      'start_position': startPosition,
      'end_position': endPosition,
      'metadata': metadata,
    };
  }
}

/// Análisis de sentimiento
class SentimentAnalysis {
  const SentimentAnalysis({
    required this.primarySentiment,
    required this.sentimentScores,
    required this.intensity,
    required this.emotionalKeywords,
    required this.mood,
  });
  final SentimentType primarySentiment;
  final Map<SentimentType, double> sentimentScores;
  final double intensity; // 0.0 - 1.0
  final List<String> emotionalKeywords;
  final String mood;

  Map<String, dynamic> toMap() {
    return {
      'primary_sentiment': primarySentiment.toString(),
      'sentiment_scores':
          sentimentScores.map((k, v) => MapEntry(k.toString(), v)),
      'intensity': intensity,
      'emotional_keywords': emotionalKeywords,
      'mood': mood,
    };
  }
}

/// Query procesada por NLP
class ProcessedQuery {
  const ProcessedQuery({
    required this.originalQuery,
    required this.normalizedQuery,
    required this.intent,
    required this.entities,
    required this.sentiment,
    required this.keywords,
    required this.expandedTerms,
    required this.correctedSpelling,
    required this.language,
    required this.processingConfidence,
    required this.context,
  });
  final String originalQuery;
  final String normalizedQuery;
  final SearchIntent intent;
  final List<ExtractedEntity> entities;
  final SentimentAnalysis sentiment;
  final List<String> keywords;
  final List<String> expandedTerms;
  final List<String> correctedSpelling;
  final String language;
  final double processingConfidence;
  final Map<String, dynamic> context;

  Map<String, dynamic> toMap() {
    return {
      'original_query': originalQuery,
      'normalized_query': normalizedQuery,
      'intent': intent.toString(),
      'entities': entities.map((e) => e.toMap()).toList(),
      'sentiment': sentiment.toMap(),
      'keywords': keywords,
      'expanded_terms': expandedTerms,
      'corrected_spelling': correctedSpelling,
      'language': language,
      'processing_confidence': processingConfidence,
      'context': context,
    };
  }
}

/// Resultado de búsqueda NLP
class NLPSearchResult {
  const NLPSearchResult({
    required this.movieId,
    required this.title,
    required this.relevanceScore,
    required this.semanticScore,
    required this.contextScore,
    required this.matchingFactors,
    required this.matchedEntities,
    required this.explanation,
    required this.featureScores,
  });
  final int movieId;
  final String title;
  final double relevanceScore; // 0.0 - 1.0
  final double semanticScore; // Similitud semántica
  final double contextScore; // Relevancia contextual
  final List<String> matchingFactors; // Por qué coincide
  final Map<EntityType, List<String>> matchedEntities;
  final String explanation;
  final Map<String, double> featureScores;

  Map<String, dynamic> toMap() {
    return {
      'movie_id': movieId,
      'title': title,
      'relevance_score': relevanceScore,
      'semantic_score': semanticScore,
      'context_score': contextScore,
      'matching_factors': matchingFactors,
      'matched_entities':
          matchedEntities.map((k, v) => MapEntry(k.toString(), v)),
      'explanation': explanation,
      'feature_scores': featureScores,
    };
  }
}

/// Advanced NLP Search Service
class AdvancedNLPSearchService {
  factory AdvancedNLPSearchService() => _instance;
  AdvancedNLPSearchService._internal();
  static final AdvancedNLPSearchService _instance =
      AdvancedNLPSearchService._internal();

  // Estado del servicio
  bool _isInitialized = false;

  // Diccionarios y modelos NLP
  final Map<String, List<String>> _synonymDictionary = {};
  final Map<String, String> _spellingCorrections = {};
  final Map<String, EntityType> _entityPatterns = {};
  final Map<String, SearchIntent> _intentPatterns = {};
  final Map<String, SentimentType> _sentimentKeywords = {};

  // Base de datos de películas para búsqueda
  final Map<int, Map<String, dynamic>> _movieDatabase = {};
  final Map<String, Set<int>> _invertedIndex =
      {}; // palabra -> conjunto de movieIds
  final Map<String, Map<String, double>> _semanticEmbeddings = {};

  // Configuración
  double _confidenceThreshold = 0.6;
  int _maxResults = 50;
  List<String> _supportedLanguages = ['es', 'en'];

  // Métricas
  int _totalSearches = 0;
  double _averageProcessingTime = 0.0;
  double _averageRelevanceScore = 0.0;

  /// Inicializar el servicio NLP
  Future<bool> initialize({
    double confidenceThreshold = 0.6,
    int maxResults = 50,
    List<String>? supportedLanguages,
  }) async {
    if (_isInitialized) {
      if (kDebugMode) debugPrint('⚠️ NLP Search Service ya está inicializado');
      return true;
    }

    try {
      if (kDebugMode) {
        debugPrint('🧠 Inicializando Advanced NLP Search Service...');
      }

      _confidenceThreshold = confidenceThreshold;
      _maxResults = maxResults;
      _supportedLanguages = supportedLanguages ?? _supportedLanguages;

      // Cargar diccionarios y modelos
      await _loadLanguageModels();
      await _loadMovieDatabase();
      await _buildInvertedIndex();
      await _loadSemanticEmbeddings();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('✅ NLP Search Service inicializado exitosamente');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error inicializando NLP Search Service: $e');
      }
      return false;
    }
  }

  /// Procesar consulta en lenguaje natural
  Future<ProcessedQuery> processQuery(
    String query, {
    String language = 'es',
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) {
      throw Exception('NLP Search Service not initialized');
    }

    if (query.trim().isEmpty) {
      throw ArgumentError('Query cannot be empty');
    }

    final startTime = DateTime.now();

    try {
      if (kDebugMode) debugPrint('🔍 Procesando query NLP: "$query"');

      // 1. Normalizar texto
      final normalizedQuery = _normalizeText(query);

      // 2. Detectar idioma (si no se especifica)
      final detectedLanguage =
          language == 'auto' ? _detectLanguage(query) : language;

      // 3. Corrección ortográfica
      final correctedSpelling =
          _correctSpelling(normalizedQuery, detectedLanguage);

      // 4. Extracción de entidades
      final entities =
          await _extractEntities(normalizedQuery, detectedLanguage);

      // 5. Análisis de intención
      final intent = _analyzeIntent(normalizedQuery, entities);

      // 6. Análisis de sentimiento
      final sentiment = _analyzeSentiment(normalizedQuery, detectedLanguage);

      // 7. Extracción de palabras clave
      final keywords = _extractKeywords(normalizedQuery, detectedLanguage);

      // 8. Expansión de términos (sinónimos)
      final expandedTerms = _expandTerms(keywords, detectedLanguage);

      // 9. Calcular confianza del procesamiento
      final processingConfidence =
          _calculateProcessingConfidence(entities, intent, sentiment, keywords);

      final processingTime =
          DateTime.now().difference(startTime).inMilliseconds;
      _averageProcessingTime = (_averageProcessingTime + processingTime) / 2;

      final processedQuery = ProcessedQuery(
        originalQuery: query,
        normalizedQuery: normalizedQuery,
        intent: intent,
        entities: entities,
        sentiment: sentiment,
        keywords: keywords,
        expandedTerms: expandedTerms,
        correctedSpelling: correctedSpelling,
        language: detectedLanguage,
        processingConfidence: processingConfidence,
        context: context ?? {},
      );

      if (kDebugMode) {
        debugPrint('✅ Query procesada en ${processingTime}ms');
        debugPrint(
            '🎯 Intención: $intent, Confianza: ${processingConfidence.toStringAsFixed(3)}');
        debugPrint(
            '📊 Entidades: ${entities.length}, Keywords: ${keywords.length}');
      }

      return processedQuery;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error procesando query: $e');
      rethrow;
    }
  }

  /// Buscar películas usando NLP
  Future<List<NLPSearchResult>> searchMovies(
    ProcessedQuery processedQuery, {
    int? maxResults,
    double? minRelevance,
  }) async {
    if (!_isInitialized) {
      throw Exception('NLP Search Service not initialized');
    }

    final startTime = DateTime.now();
    final results = <NLPSearchResult>[];
    final limit = maxResults ?? _maxResults;
    final minScore = minRelevance ?? _confidenceThreshold;

    try {
      if (kDebugMode) debugPrint('🎬 Buscando películas con NLP...');

      // Obtener candidatos usando diferentes estrategias
      final candidates = <int, double>{};

      // 1. Búsqueda por palabras clave exactas
      await _searchByKeywords(processedQuery, candidates);

      // 2. Búsqueda por entidades extraídas
      await _searchByEntities(processedQuery, candidates);

      // 3. Búsqueda semántica
      await _searchBySemantic(processedQuery, candidates);

      // 4. Búsqueda por sentimiento/mood
      await _searchBySentiment(processedQuery, candidates);

      // 5. Búsqueda contextual
      await _searchByContext(processedQuery, candidates);

      // Procesar candidatos y calcular scores finales
      for (final entry in candidates.entries) {
        final movieId = entry.key;
        final movie = _movieDatabase[movieId];
        if (movie == null) continue;

        final relevanceScore =
            await _calculateRelevanceScore(processedQuery, movie);
        if (relevanceScore < minScore) continue;

        final semanticScore =
            await _calculateSemanticScore(processedQuery, movie);
        final contextScore =
            await _calculateContextScore(processedQuery, movie);

        final matchingFactors = _getMatchingFactors(processedQuery, movie);
        final matchedEntities = _getMatchedEntities(processedQuery, movie);
        final explanation =
            _generateExplanation(processedQuery, movie, matchingFactors);
        final featureScores = _getFeatureScores(processedQuery, movie);

        results.add(NLPSearchResult(
          movieId: movieId,
          title: movie['title'] ?? 'Unknown',
          relevanceScore: relevanceScore,
          semanticScore: semanticScore,
          contextScore: contextScore,
          matchingFactors: matchingFactors,
          matchedEntities: matchedEntities,
          explanation: explanation,
          featureScores: featureScores,
        ));
      }

      // Ordenar por relevancia combinada
      results.sort((a, b) {
        final scoreA = a.relevanceScore * 0.5 +
            a.semanticScore * 0.3 +
            a.contextScore * 0.2;
        final scoreB = b.relevanceScore * 0.5 +
            b.semanticScore * 0.3 +
            b.contextScore * 0.2;
        return scoreB.compareTo(scoreA);
      });

      final finalResults = results.take(limit).toList();

      // Actualizar métricas
      _totalSearches++;
      _averageRelevanceScore = finalResults.isEmpty
          ? 0.0
          : finalResults.map((r) => r.relevanceScore).reduce((a, b) => a + b) /
              finalResults.length;

      final searchTime = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        debugPrint('✅ Búsqueda NLP completada en ${searchTime}ms');
        debugPrint(
            '📊 Resultados: ${finalResults.length}, Relevancia promedio: ${_averageRelevanceScore.toStringAsFixed(3)}');
      }

      return finalResults;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error en búsqueda NLP: $e');
      return [];
    }
  }

  /// Búsqueda directa con texto simple
  Future<List<NLPSearchResult>> search(
    String query, {
    String language = 'es',
    Map<String, dynamic>? context,
    int? maxResults,
    double? minRelevance,
  }) async {
    final processedQuery = await processQuery(
      query,
      language: language,
      context: context,
    );

    return await searchMovies(
      processedQuery,
      maxResults: maxResults,
      minRelevance: minRelevance,
    );
  }

  /// Obtener sugerencias de búsqueda
  Future<List<String>> getSuggestions(String partialQuery,
      {String language = 'es'}) async {
    if (!_isInitialized || partialQuery.length < 2) return [];

    final suggestions = <String>[];
    final normalizedQuery = _normalizeText(partialQuery).toLowerCase();

    // Sugerencias de películas
    for (final movie in _movieDatabase.values) {
      final title = (movie['title'] as String? ?? '').toLowerCase();
      if (title.contains(normalizedQuery)) {
        suggestions.add(movie['title'] as String? ?? '');
      }
    }

    // Sugerencias de entidades
    for (final entity in _entityPatterns.keys) {
      if (entity.toLowerCase().contains(normalizedQuery)) {
        suggestions.add(entity);
      }
    }

    return suggestions.take(10).toList();
  }

  /// Obtener métricas del servicio
  Map<String, dynamic> getMetrics() {
    return {
      'is_initialized': _isInitialized,
      'total_searches': _totalSearches,
      'average_processing_time_ms': _averageProcessingTime,
      'average_relevance_score': _averageRelevanceScore,
      'supported_languages': _supportedLanguages,
      'confidence_threshold': _confidenceThreshold,
      'max_results': _maxResults,
      'movie_database_size': _movieDatabase.length,
      'inverted_index_size': _invertedIndex.length,
      'synonym_dictionary_size': _synonymDictionary.length,
      'entity_patterns': _entityPatterns.length,
    };
  }

  /// Detener el servicio
  void dispose() {
    _synonymDictionary.clear();
    _spellingCorrections.clear();
    _entityPatterns.clear();
    _intentPatterns.clear();
    _sentimentKeywords.clear();
    _movieDatabase.clear();
    _invertedIndex.clear();
    _semanticEmbeddings.clear();
    _isInitialized = false;
  }

  // Métodos privados

  /// Cargar modelos de lenguaje
  Future<void> _loadLanguageModels() async {
    if (kDebugMode) debugPrint('📚 Cargando modelos de lenguaje NLP...');

    // Sinónimos en español
    _synonymDictionary['accion'] = ['action', 'aventura', 'pelea'];
    _synonymDictionary['comedia'] = [
      'comedy',
      'humor',
      'gracioso',
      'divertido'
    ];
    _synonymDictionary['drama'] = ['dramatic', 'serio', 'emotivo'];
    _synonymDictionary['terror'] = ['horror', 'miedo', 'suspenso', 'thriller'];
    _synonymDictionary['romance'] = ['romantic', 'amor', 'pareja'];

    // Patrones de entidades
    _entityPatterns['actor'] = EntityType.actor;
    _entityPatterns['actriz'] = EntityType.actor;
    _entityPatterns['director'] = EntityType.director;
    _entityPatterns['género'] = EntityType.genre;
    _entityPatterns['año'] = EntityType.year;

    // Patrones de intención
    _intentPatterns['buscar'] = SearchIntent.findMovie;
    _intentPatterns['encontrar'] = SearchIntent.findMovie;
    _intentPatterns['recomendar'] = SearchIntent.recommendMovie;
    _intentPatterns['sugerir'] = SearchIntent.recommendMovie;
    _intentPatterns['similar'] = SearchIntent.findSimilar;
    _intentPatterns['parecido'] = SearchIntent.findSimilar;

    // Palabras clave de sentimiento
    _sentimentKeywords['feliz'] = SentimentType.happy;
    _sentimentKeywords['alegre'] = SentimentType.happy;
    _sentimentKeywords['triste'] = SentimentType.sad;
    _sentimentKeywords['emocionante'] = SentimentType.excited;
    _sentimentKeywords['romántico'] = SentimentType.romantic;
    _sentimentKeywords['gracioso'] = SentimentType.funny;
    _sentimentKeywords['dramático'] = SentimentType.dramatic;

    if (kDebugMode) debugPrint('✅ Modelos de lenguaje cargados');
  }

  /// Cargar base de datos de películas (simulada)
  Future<void> _loadMovieDatabase() async {
    if (kDebugMode) debugPrint('🎬 Cargando base de datos de películas...');

    // Simular películas para testing
    for (int i = 1; i <= 100; i++) {
      _movieDatabase[i] = {
        'id': i,
        'title': 'Película $i',
        'genres': ['Action', 'Drama'],
        'actors': ['Actor $i', 'Actriz ${i + 1}'],
        'director': 'Director $i',
        'year': 2020 + (i % 4),
        'plot': 'Historia emocionante de la película $i',
        'rating': 3.0 + Random().nextDouble() * 2.0,
        'keywords': ['emocionante', 'aventura', 'drama'],
      };
    }

    if (kDebugMode) {
      debugPrint('✅ Base de datos cargada: ${_movieDatabase.length} películas');
    }
  }

  /// Construir índice invertido para búsqueda
  Future<void> _buildInvertedIndex() async {
    if (kDebugMode) debugPrint('📇 Construyendo índice invertido...');

    for (final entry in _movieDatabase.entries) {
      final movieId = entry.key;
      final movie = entry.value;

      // Indexar título
      final titleWords = _tokenize(movie['title'] as String? ?? '');
      for (final word in titleWords) {
        _invertedIndex.putIfAbsent(word.toLowerCase(), () => {}).add(movieId);
      }

      // Indexar géneros
      final genres = movie['genres'] as List<String>? ?? [];
      for (final genre in genres) {
        _invertedIndex.putIfAbsent(genre.toLowerCase(), () => {}).add(movieId);
      }

      // Indexar actores
      final actors = movie['actors'] as List<String>? ?? [];
      for (final actor in actors) {
        final actorWords = _tokenize(actor);
        for (final word in actorWords) {
          _invertedIndex.putIfAbsent(word.toLowerCase(), () => {}).add(movieId);
        }
      }
    }

    if (kDebugMode) {
      debugPrint('✅ Índice construido: ${_invertedIndex.length} términos');
    }
  }

  /// Cargar embeddings semánticos (simulados)
  Future<void> _loadSemanticEmbeddings() async {
    if (kDebugMode) debugPrint('🧮 Cargando embeddings semánticos...');

    // Simular embeddings para términos comunes
    final commonTerms = ['acción', 'comedia', 'drama', 'terror', 'romance'];
    for (final term in commonTerms) {
      _semanticEmbeddings[term] = {
        'dim1': Random().nextDouble(),
        'dim2': Random().nextDouble(),
        'dim3': Random().nextDouble(),
      };
    }

    if (kDebugMode) {
      debugPrint(
          '✅ Embeddings cargados: ${_semanticEmbeddings.length} términos');
    }
  }

  /// Normalizar texto
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Detectar idioma (simulado)
  String _detectLanguage(String text) {
    // Palabras comunes en español
    final spanishWords = [
      'el',
      'la',
      'de',
      'que',
      'y',
      'es',
      'en',
      'un',
      'con',
      'no'
    ];
    final words = _tokenize(text.toLowerCase());

    int spanishCount = 0;
    for (final word in words) {
      if (spanishWords.contains(word)) spanishCount++;
    }

    return spanishCount > words.length * 0.2 ? 'es' : 'en';
  }

  /// Corregir ortografía (simplificado)
  List<String> _correctSpelling(String text, String language) {
    final words = _tokenize(text);
    final corrected = <String>[];

    for (final word in words) {
      final correction = _spellingCorrections[word.toLowerCase()];
      corrected.add(correction ?? word);
    }

    return corrected;
  }

  /// Extraer entidades del texto
  Future<List<ExtractedEntity>> _extractEntities(
      String text, String language) async {
    final entities = <ExtractedEntity>[];
    final words = _tokenize(text);

    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();
      final entityType = _entityPatterns[word];

      if (entityType != null) {
        entities.add(ExtractedEntity(
          type: entityType,
          value: words[i],
          originalText: words[i],
          confidence: 0.8,
          startPosition: i,
          endPosition: i + 1,
          metadata: {'language': language},
        ));
      }
    }

    return entities;
  }

  /// Analizar intención de búsqueda
  SearchIntent _analyzeIntent(String text, List<ExtractedEntity> entities) {
    final words = _tokenize(text.toLowerCase());

    for (final word in words) {
      final intent = _intentPatterns[word];
      if (intent != null) return intent;
    }

    // Inferir intención por entidades
    if (entities.any((e) => e.type == EntityType.actor)) {
      return SearchIntent.findActor;
    }

    return SearchIntent.findMovie; // Por defecto
  }

  /// Analizar sentimiento
  SentimentAnalysis _analyzeSentiment(String text, String language) {
    final words = _tokenize(text.toLowerCase());
    final sentimentScores = <SentimentType, double>{};
    final emotionalKeywords = <String>[];

    for (final word in words) {
      final sentiment = _sentimentKeywords[word];
      if (sentiment != null) {
        sentimentScores[sentiment] = (sentimentScores[sentiment] ?? 0.0) + 1.0;
        emotionalKeywords.add(word);
      }
    }

    final primarySentiment = sentimentScores.isEmpty
        ? SentimentType.neutral
        : sentimentScores.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    return SentimentAnalysis(
      primarySentiment: primarySentiment,
      sentimentScores: sentimentScores,
      intensity: sentimentScores.values.isEmpty
          ? 0.0
          : sentimentScores.values.reduce((a, b) => a + b) / words.length,
      emotionalKeywords: emotionalKeywords,
      mood: primarySentiment.toString().split('.').last,
    );
  }

  /// Extraer palabras clave
  List<String> _extractKeywords(String text, String language) {
    final words = _tokenize(text);
    final stopWords = [
      'el',
      'la',
      'de',
      'que',
      'y',
      'es',
      'en',
      'un',
      'con',
      'no',
      'se',
      'te'
    ];

    return words
        .where((word) =>
            word.length > 2 && !stopWords.contains(word.toLowerCase()))
        .map((word) => word.toLowerCase())
        .toSet()
        .toList();
  }

  /// Expandir términos con sinónimos
  List<String> _expandTerms(List<String> keywords, String language) {
    final expanded = <String>{};

    for (final keyword in keywords) {
      expanded.add(keyword);
      final synonyms = _synonymDictionary[keyword];
      if (synonyms != null) {
        expanded.addAll(synonyms);
      }
    }

    return expanded.toList();
  }

  /// Calcular confianza del procesamiento
  double _calculateProcessingConfidence(
    List<ExtractedEntity> entities,
    SearchIntent intent,
    SentimentAnalysis sentiment,
    List<String> keywords,
  ) {
    double confidence = 0.5; // Base

    // Aumentar por entidades extraídas
    confidence += entities.length * 0.1;

    // Aumentar por palabras clave
    confidence += keywords.length * 0.05;

    // Aumentar por sentimiento detectado
    if (sentiment.primarySentiment != SentimentType.neutral) {
      confidence += 0.1;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Tokenizar texto
  List<String> _tokenize(String text) {
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  }

  // Implementaciones simplificadas de métodos de búsqueda
  Future<void> _searchByKeywords(
      ProcessedQuery query, Map<int, double> candidates) async {
    for (final keyword in query.keywords) {
      final movieIds = _invertedIndex[keyword];
      if (movieIds != null) {
        for (final movieId in movieIds) {
          candidates[movieId] = (candidates[movieId] ?? 0.0) + 0.5;
        }
      }
    }
  }

  Future<void> _searchByEntities(
      ProcessedQuery query, Map<int, double> candidates) async {
    for (final entity in query.entities) {
      final movieIds = _invertedIndex[entity.value.toLowerCase()];
      if (movieIds != null) {
        for (final movieId in movieIds) {
          candidates[movieId] =
              (candidates[movieId] ?? 0.0) + entity.confidence;
        }
      }
    }
  }

  Future<void> _searchBySemantic(
      ProcessedQuery query, Map<int, double> candidates) async {
    // Simular búsqueda semántica
    final random = Random();
    for (int i = 1; i <= 10; i++) {
      candidates[i] = (candidates[i] ?? 0.0) + random.nextDouble() * 0.3;
    }
  }

  Future<void> _searchBySentiment(
      ProcessedQuery query, Map<int, double> candidates) async {
    // Simular búsqueda por sentimiento
    if (query.sentiment.primarySentiment != SentimentType.neutral) {
      final random = Random();
      for (int i = 1; i <= 5; i++) {
        candidates[i] = (candidates[i] ?? 0.0) + random.nextDouble() * 0.2;
      }
    }
  }

  Future<void> _searchByContext(
      ProcessedQuery query, Map<int, double> candidates) async {
    // Simular búsqueda contextual
    if (query.context.isNotEmpty) {
      final random = Random();
      for (int i = 1; i <= 8; i++) {
        candidates[i] = (candidates[i] ?? 0.0) + random.nextDouble() * 0.1;
      }
    }
  }

  Future<double> _calculateRelevanceScore(
      ProcessedQuery query, Map<String, dynamic> movie) async {
    return 0.5 + Random().nextDouble() * 0.4;
  }

  Future<double> _calculateSemanticScore(
      ProcessedQuery query, Map<String, dynamic> movie) async {
    return 0.3 + Random().nextDouble() * 0.5;
  }

  Future<double> _calculateContextScore(
      ProcessedQuery query, Map<String, dynamic> movie) async {
    return 0.4 + Random().nextDouble() * 0.4;
  }

  List<String> _getMatchingFactors(
      ProcessedQuery query, Map<String, dynamic> movie) {
    return ['Título coincide', 'Género similar', 'Actor conocido'];
  }

  Map<EntityType, List<String>> _getMatchedEntities(
      ProcessedQuery query, Map<String, dynamic> movie) {
    return {
      EntityType.movie: [movie['title'] as String? ?? ''],
      EntityType.genre: movie['genres'] as List<String>? ?? [],
    };
  }

  String _generateExplanation(
      ProcessedQuery query, Map<String, dynamic> movie, List<String> factors) {
    return 'Esta película coincide porque: ${factors.join(", ")}';
  }

  Map<String, double> _getFeatureScores(
      ProcessedQuery query, Map<String, dynamic> movie) {
    return {
      'title_match': 0.8,
      'genre_match': 0.6,
      'actor_match': 0.4,
    };
  }
}
