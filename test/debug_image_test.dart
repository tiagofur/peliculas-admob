import 'package:flutter/material.dart';
import 'package:peliculas_admob/core/cache/image_cache_manager.dart';
import 'package:peliculas_admob/services/hybrid_image_service.dart';
import 'package:peliculas_admob/core/utils/logger_factory.dart';

class DebugImageTest extends StatefulWidget {
  const DebugImageTest({super.key});

  @override
  State<DebugImageTest> createState() => _DebugImageTestState();
}

class _DebugImageTestState extends State<DebugImageTest> {
  final _logger = LoggerFactory.logger;
  String _status = 'Iniciando prueba...';
  ImageProvider? _imageProvider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testImageLoading();
  }

  Future<void> _testImageLoading() async {
    try {
      setState(() {
        _status = 'Verificando inicialización de ImageCacheManager...';
      });

      // Verificar si ImageCacheManager está inicializado
      final stats = await ImageCacheManager.instance.getStats();
      _logger.info('📊 Cache stats: $stats');

      setState(() {
        _status = 'Cache inicializado. Probando descarga de imagen...';
      });

      // URL de prueba de TMDB
      const testUrl = 'https://image.tmdb.org/t/p/w500/1E5baAaEse26fej7uHcjOgEE2t2.jpg';
      
      _logger.info('🔍 Probando descarga de: $testUrl');

      // Probar getCachedImage directamente
      final imageProvider = await ImageCacheManager.instance.getCachedImage(testUrl);
      
      if (imageProvider != null) {
        setState(() {
          _imageProvider = imageProvider;
          _status = '✅ Imagen cargada exitosamente con ImageCacheManager';
          _isLoading = false;
        });
        _logger.info('✅ ImageCacheManager funcionando correctamente');
      } else {
        setState(() {
          _status = '❌ ImageCacheManager devolvió null';
          _isLoading = false;
        });
        _logger.error('❌ ImageCacheManager.getCachedImage devolvió null');
        
        // Probar con HybridImageService
        await _testHybridImageService(testUrl);
      }
    } catch (e, stackTrace) {
      setState(() {
        _status = '❌ Error: $e';
        _isLoading = false;
      });
      _logger.error('❌ Error en prueba de imagen: $e', stackTrace);
    }
  }

  Future<void> _testHybridImageService(String url) async {
    try {
      setState(() {
        _status = 'Probando HybridImageService...';
      });

      final hybridProvider = await HybridImageService.instance.getOptimizedImageProvider(url);
      
      setState(() {
        _imageProvider = hybridProvider;
        _status = '✅ Imagen cargada con HybridImageService';
      });
      _logger.info('✅ HybridImageService funcionando correctamente');
    } catch (e) {
      setState(() {
        _status = '❌ Error en HybridImageService: $e';
      });
      _logger.error('❌ Error en HybridImageService: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Image Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado:',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_imageProvider != null)
              Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: _imageProvider!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.red[100],
                        child: const Center(
                          child: Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 50,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 200,
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 50,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No se pudo cargar\nla imagen',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _imageProvider = null;
                  _status = 'Reiniciando prueba...';
                });
                _testImageLoading();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}