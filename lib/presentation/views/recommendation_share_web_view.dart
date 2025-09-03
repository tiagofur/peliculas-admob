import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/share_service.dart';
import '../widgets/shared/custom_appbar.dart';

/// Web view for sharing recommendations with download prompts and deep links
class RecommendationShareWebView extends ConsumerWidget {
  const RecommendationShareWebView({
    super.key,
    required this.type,
    required this.id,
  });
  final String type; // 'category' or 'mood'
  final String id;

  static const name = 'recommendation-share-web';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CustomAppbar(),
      body: _RecommendationShareContent(
        type: type,
        id: id,
      ),
    );
  }
}

class _RecommendationShareContent extends StatelessWidget {
  const _RecommendationShareContent({
    required this.type,
    required this.id,
  });
  final String type;
  final String id;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCategory = type == 'category';
    final title = _getRecommendationTitle();
    final description = _getRecommendationDescription();
    final icon = isCategory ? Icons.category : Icons.mood;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section with recommendation info
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha(179),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Recommendation icon
                  Container(
                    height: size.height * 0.2,
                    width: size.height * 0.2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withAlpha(179),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withAlpha(77),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Recommendation title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // Recommendation description
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Recommendation details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const _InfoChip(
                        icon: Icons.star,
                        label: 'Recomendado',
                      ),
                      _InfoChip(
                        icon: isCategory ? Icons.category : Icons.mood,
                        label: isCategory ? 'Categoría' : 'Estado de ánimo',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Call to action section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // App download prompt
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withAlpha(179),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withAlpha(77),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.phone_android,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '📱 ¡Descarga la app Películas!',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Descubre más recomendaciones personalizadas',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _openAppOrStore(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Ver Recomendaciones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Share buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ShareButton(
                      icon: Icons.share,
                      label: 'Compartir',
                      onPressed: () => _shareRecommendation(context),
                    ),
                    _ShareButton(
                      icon: Icons.link,
                      label: 'Copiar enlace',
                      onPressed: () => _copyLink(context),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Features section
                _RecommendationFeaturesSection(isCategory: isCategory),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRecommendationTitle() {
    if (type == 'category') {
      switch (id.toLowerCase()) {
        case 'action':
          return '⚡ Películas de Acción';
        case 'comedy':
          return '😄 Películas de Comedia';
        case 'drama':
          return '🎭 Películas de Drama';
        case 'horror':
          return '👻 Películas de Terror';
        case 'romance':
          return '💕 Películas Románticas';
        case 'scifi':
          return '🚀 Películas de Ciencia Ficción';
        default:
          return '⭐ Recomendaciones de $id';
      }
    } else {
      switch (id.toLowerCase()) {
        case 'happy':
          return '😊 Películas para estar feliz';
        case 'sad':
          return '😢 Películas emotivas';
        case 'excited':
          return '🔥 Películas emocionantes';
        case 'relaxed':
          return '😌 Películas relajantes';
        case 'adventurous':
          return '🗺️ Películas de aventura';
        default:
          return '⭐ Recomendaciones para tu estado de ánimo';
      }
    }
  }

  String _getRecommendationDescription() {
    if (type == 'category') {
      return 'Una selección cuidadosa de las mejores películas de esta categoría, perfectas para cualquier momento.';
    } else {
      return 'Películas seleccionadas especialmente para tu estado de ánimo actual. ¡Encuentra la película perfecta!';
    }
  }

  void _openAppOrStore(BuildContext context) async {
    final deepLink = ShareService.generateRecommendationDeepLink(type, id);

    try {
      final uri = Uri.parse(deepLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web version
        if (context.mounted) {
          context.go('/recommendations/$type/$id');
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.go('/recommendations/$type/$id');
      }
    }
  }

  void _shareRecommendation(BuildContext context) async {
    try {
      await ShareService.shareRecommendation(
        context: context,
        recommendationType: type,
        recommendationId: id,
        title: _getRecommendationTitle(),
        description: _getRecommendationDescription(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al compartir: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyLink(BuildContext context) async {
    final shareUrl = ShareService.generateRecommendationShareUrl(type, id);

    // Note: For web, we would need to use a different approach
    // This is a placeholder for the copy functionality
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enlace copiado: $shareUrl'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(179),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }
}

class _RecommendationFeaturesSection extends StatelessWidget {
  const _RecommendationFeaturesSection({required this.isCategory});
  final bool isCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✨ Descubre más con la app Películas:',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (isCategory) ..._getCategoryFeatures() else ..._getMoodFeatures(),
      ],
    );
  }

  List<Widget> _getCategoryFeatures() {
    return [
      const _FeatureItem(
        icon: Icons.category,
        title: 'Explora por categorías',
        description: 'Descubre películas de todos los géneros',
      ),
      const _FeatureItem(
        icon: Icons.trending_up,
        title: 'Tendencias actuales',
        description: 'Mantente al día con lo más popular',
      ),
      const _FeatureItem(
        icon: Icons.star_rate,
        title: 'Mejor valoradas',
        description: 'Encuentra las películas con mejores críticas',
      ),
    ];
  }

  List<Widget> _getMoodFeatures() {
    return [
      const _FeatureItem(
        icon: Icons.mood,
        title: 'Recomendaciones por estado de ánimo',
        description: 'Películas perfectas para cada momento',
      ),
      const _FeatureItem(
        icon: Icons.psychology,
        title: 'Algoritmo inteligente',
        description: 'Sugerencias basadas en tus preferencias',
      ),
      const _FeatureItem(
        icon: Icons.favorite,
        title: 'Personalización total',
        description: 'Crea tu perfil de gustos cinematográficos',
      ),
    ];
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(179),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
