import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb y Uint8List
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.avatarUrl,
    this.avatarHash,
    this.selectedImage,
    this.selectedImageBytes,
    this.size = 120,
    this.onTap,
    this.showEditIcon = false,
    this.heroTag,
  });
  final String? avatarUrl;
  final String? avatarHash;
  final File? selectedImage;
  final Uint8List? selectedImageBytes;
  final double size;
  final VoidCallback? onTap;
  final bool showEditIcon;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: _buildAvatarContent(theme),
      ),
    );

    if (heroTag != null) {
      avatarWidget = Hero(
        tag: heroTag!,
        child: avatarWidget,
      );
    }

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    if (showEditIcon) {
      return Stack(
        children: [
          avatarWidget,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.edit,
                color: theme.colorScheme.onPrimary,
                size: size * 0.12,
              ),
            ),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  Widget _buildAvatarContent(ThemeData theme) {
    // Si hay una imagen seleccionada localmente, mostrarla
    // En Web, usar bytes; en otras plataformas, usar File
    if (kIsWeb && selectedImageBytes != null) {
      return Image.memory(
        selectedImageBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar(theme);
        },
      );
    }

    if (!kIsWeb && selectedImage != null) {
      return Image.file(
        selectedImage!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar(theme);
        },
      );
    }

    // Si hay una URL de avatar, cargarla desde la red
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheKey: _buildCacheKey(),
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Shimmer.fromColors(
            baseColor:
                theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
            highlightColor: theme.colorScheme.surface.withValues(alpha: 0.3),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: theme.colorScheme.surface,
            ),
          ),
        ),
        errorWidget: (context, url, error) {
          return _buildDefaultAvatar(theme);
        },
      );
    }

    // Avatar por defecto
    return _buildDefaultAvatar(theme);
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.8),
            theme.colorScheme.secondary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Icon(
        Icons.person,
        size: size * 0.5,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }

  String? _buildCacheKey() {
    if (avatarUrl == null) {
      return null;
    }
    if (avatarHash == null || avatarHash!.isEmpty) {
      return avatarUrl;
    }
    return '${avatarUrl}_$avatarHash';
  }
}

// Widget auxiliar para avatares pequeños en listas
class SmallProfileAvatar extends StatelessWidget {
  const SmallProfileAvatar({
    super.key,
    this.avatarUrl,
    this.avatarHash,
    this.size = 40,
    this.heroTag,
  });
  final String? avatarUrl;
  final String? avatarHash;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      avatarUrl: avatarUrl,
      avatarHash: avatarHash,
      size: size,
      heroTag: heroTag,
    );
  }
}

// Widget para mostrar avatar con información del usuario
class UserAvatarWithInfo extends StatelessWidget {
  const UserAvatarWithInfo({
    super.key,
    this.avatarUrl,
    this.avatarHash,
    required this.fullName,
    this.subtitle,
    this.avatarSize = 50,
    this.onTap,
  });
  final String? avatarUrl;
  final String? avatarHash;
  final String fullName;
  final String? subtitle;
  final double avatarSize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ProfileAvatar(
              avatarUrl: avatarUrl,
              avatarHash: avatarHash,
              size: avatarSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
