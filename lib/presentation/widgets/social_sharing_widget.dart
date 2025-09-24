import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/movie.dart';
import '../../services/social_sharing_service.dart';
import '../providers/social_sharing_provider.dart';

/// Widget para compartir una película con múltiples opciones
class MovieSharingWidget extends ConsumerWidget {
  const MovieSharingWidget({
    super.key,
    required this.movie,
    this.customMessage,
    this.showQuickActions = true,
  });
  final Movie movie;
  final String? customMessage;
  final bool showQuickActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shareState = ref.watch(shareStateProvider);
    final shareNotifier = ref.read(shareStateProvider.notifier);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Compartir película',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyMovieLink(context, ref, movie),
                  tooltip: 'Copiar enlace',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick actions
            if (showQuickActions) ...[
              const Text(
                'Acciones rápidas:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickActionChip(
                    context,
                    icon: Icons.recommend,
                    label: 'Recomendar',
                    onPressed: () => shareNotifier.shareMovie(
                      movie: movie,
                      customMessage: customMessage,
                      context: ShareContext.recommendation,
                    ),
                  ),
                  _buildQuickActionChip(
                    context,
                    icon: Icons.favorite,
                    label: 'Favorita',
                    onPressed: () => shareNotifier.shareMovie(
                      movie: movie,
                      customMessage: customMessage,
                      context: ShareContext.favorite,
                    ),
                  ),
                  _buildQuickActionChip(
                    context,
                    icon: Icons.list,
                    label: 'Añadir a lista',
                    onPressed: () => shareNotifier.shareMovie(
                      movie: movie,
                      customMessage: customMessage,
                      context: ShareContext.watchlist,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Main share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: shareState is ShareStateLoading
                    ? null
                    : () => _showShareOptionsBottomSheet(context, ref, movie),
                icon: shareState is ShareStateLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(
                  shareState is ShareStateLoading
                      ? 'Compartiendo...'
                      : 'Más opciones de compartir',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // State feedback
            if (shareState is ShareStateSuccess) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shareState.message,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (shareState is ShareStateError) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shareState.message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
      ),
    );
  }

  void _copyMovieLink(BuildContext context, WidgetRef ref, Movie movie) async {
    final shareNotifier = ref.read(shareStateProvider.notifier);
    final deepLink = shareNotifier.generateMovieDeepLink(movie);
    await shareNotifier.copyToClipboard(deepLink);
  }

  void _showShareOptionsBottomSheet(
      BuildContext context, WidgetRef ref, Movie movie) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ShareOptionsBottomSheet(
        movie: movie,
        customMessage: customMessage,
      ),
    );
  }
}

/// Bottom sheet con opciones detalladas de compartir
class ShareOptionsBottomSheet extends ConsumerStatefulWidget {
  const ShareOptionsBottomSheet({
    super.key,
    required this.movie,
    this.customMessage,
  });
  final Movie movie;
  final String? customMessage;

  @override
  ConsumerState<ShareOptionsBottomSheet> createState() =>
      _ShareOptionsBottomSheetState();
}

class _ShareOptionsBottomSheetState
    extends ConsumerState<ShareOptionsBottomSheet> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _messageController.text = widget.customMessage ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Text(
                        'Compartir película',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Movie info
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 60,
                                height: 90,
                                child: widget.movie.posterPath.isNotEmpty
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w154${widget.movie.posterPath}',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.movie),
                                      )
                                    : const Icon(Icons.movie),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.movie.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${widget.movie.releaseDate.year}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (widget.movie.voteAverage > 0) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${widget.movie.voteAverage.toStringAsFixed(1)}/10',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Custom message
                        const Text(
                          'Mensaje personalizado:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText:
                                'Añade un mensaje personalizado (opcional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Share options
                        const Text(
                          'Opciones de compartir:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildShareOptionTile(
                          icon: Icons.recommend,
                          title: 'Recomendar película',
                          subtitle: 'Comparte como recomendación',
                          onTap: () =>
                              _shareWithContext(ShareContext.recommendation),
                        ),

                        _buildShareOptionTile(
                          icon: Icons.favorite,
                          title: 'Película favorita',
                          subtitle: 'Comparte como una de tus favoritas',
                          onTap: () => _shareWithContext(ShareContext.favorite),
                        ),

                        _buildShareOptionTile(
                          icon: Icons.list,
                          title: 'Añadir a lista',
                          subtitle: 'Comparte que la tienes en tu watchlist',
                          onTap: () =>
                              _shareWithContext(ShareContext.watchlist),
                        ),

                        _buildShareOptionTile(
                          icon: Icons.share,
                          title: 'Compartir general',
                          subtitle: 'Compartir información básica',
                          onTap: () => _shareWithContext(ShareContext.general),
                        ),

                        _buildShareOptionTile(
                          icon: Icons.link,
                          title: 'Compartir con enlace',
                          subtitle: 'Incluye enlace directo a la película',
                          onTap: () => _shareWithDeepLink(),
                        ),

                        _buildShareOptionTile(
                          icon: Icons.copy,
                          title: 'Copiar enlace',
                          subtitle: 'Copia el enlace al portapapeles',
                          onTap: () => _copyDeepLink(),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShareOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _shareWithContext(ShareContext shareContext) async {
    final shareNotifier = ref.read(shareStateProvider.notifier);
    await shareNotifier.shareMovie(
      movie: widget.movie,
      customMessage:
          _messageController.text.isEmpty ? null : _messageController.text,
      context: shareContext,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _shareWithDeepLink() async {
    final shareService = ref.read(socialSharingServiceProvider);
    await shareService.shareMovieWithDeepLink(
      movie: widget.movie,
      customMessage:
          _messageController.text.isEmpty ? null : _messageController.text,
      includeAppInvitation: true,
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _copyDeepLink() async {
    final shareNotifier = ref.read(shareStateProvider.notifier);
    final deepLink = shareNotifier.generateMovieDeepLink(widget.movie);
    await shareNotifier.copyToClipboard(deepLink);
    if (mounted) Navigator.of(context).pop();
  }
}

/// Widget compacto para compartir en listas o cards de películas
class CompactShareButton extends ConsumerWidget {
  const CompactShareButton({
    super.key,
    required this.movie,
    this.context = ShareContext.general,
  });
  final Movie movie;
  final ShareContext context;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.share, size: 20),
      onPressed: () => _showQuickShareMenu(context, ref),
      tooltip: 'Compartir',
    );
  }

  void _showQuickShareMenu(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Compartir "${movie.title}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Compartir película'),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(shareStateProvider.notifier).shareMovie(
                      movie: movie,
                      context: this.context,
                    );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copiar enlace'),
              onTap: () {
                Navigator.of(context).pop();
                final shareNotifier = ref.read(shareStateProvider.notifier);
                final deepLink = shareNotifier.generateMovieDeepLink(movie);
                shareNotifier.copyToClipboard(deepLink);
              },
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('Más opciones'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => ShareOptionsBottomSheet(movie: movie),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
