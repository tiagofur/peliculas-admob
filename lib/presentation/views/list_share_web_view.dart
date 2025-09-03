import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/share_service.dart';
import '../widgets/shared/custom_appbar.dart';

/// Web view for sharing movie lists with download prompts and deep links
class ListShareWebView extends ConsumerWidget {
  const ListShareWebView({super.key, required this.listId});
  final String listId;

  static const name = 'list-share-web';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, we'll create a placeholder since we don't have list providers yet
    // This will be updated when list management is fully implemented

    return Scaffold(
      appBar: const CustomAppbar(),
      body: _ListShareContent(listId: listId),
    );
  }
}

class _ListShareContent extends StatelessWidget {
  const _ListShareContent({required this.listId});
  final String listId;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero section with list info
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
                  // List icon
                  Container(
                    height: size.height * 0.2,
                    width: size.height * 0.2,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withAlpha(179),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.list_alt,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // List title
                  Text(
                    '📋 Lista de Películas',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  // List description
                  Text(
                    'Descubre esta increíble colección de películas seleccionadas especialmente para ti.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // List details
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _InfoChip(
                        icon: Icons.movie,
                        label: 'Películas',
                      ),
                      _InfoChip(
                        icon: Icons.star,
                        label: 'Curadas',
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
                        'Accede a todas las listas y descubre más películas',
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
                          'Ver Lista Completa',
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
                      onPressed: () => _shareList(context),
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
                _FeaturesSection(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAppOrStore(BuildContext context) async {
    final deepLink = ShareService.generateListDeepLink(listId);

    try {
      final uri = Uri.parse(deepLink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web version
        if (context.mounted) {
          context.go('/lists/$listId');
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.go('/lists/$listId');
      }
    }
  }

  void _shareList(BuildContext context) async {
    try {
      await ShareService.shareMovieList(
        context: context,
        listId: listId,
        listName: 'Lista de Películas',
        listDescription: 'Una increíble colección de películas seleccionadas',
        movieCount: 0, // This would be dynamic in a real implementation
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
    final shareUrl = ShareService.generateListShareUrl(listId);

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

class _FeaturesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✨ Con la app Películas puedes:',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        const _FeatureItem(
          icon: Icons.list_alt,
          title: 'Crear listas personalizadas',
          description: 'Organiza tus películas favoritas en listas temáticas',
        ),
        const _FeatureItem(
          icon: Icons.star,
          title: 'Descubrir recomendaciones',
          description: 'Encuentra nuevas películas basadas en tus gustos',
        ),
        const _FeatureItem(
          icon: Icons.share,
          title: 'Compartir con amigos',
          description: 'Comparte tus listas y películas favoritas',
        ),
        const _FeatureItem(
          icon: Icons.bookmark,
          title: 'Marcar como vistas',
          description: 'Lleva un registro de las películas que has visto',
        ),
      ],
    );
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
