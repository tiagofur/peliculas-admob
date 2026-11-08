import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/logger_factory.dart';
import '../../../core/utils/tmdb_image_utils.dart';
import '../../../domain/entities/actor_details.dart';
import '../../providers/actors/actor_details_provider.dart';
import '../../widgets/skeletons/skeletons.dart';

class ActorScreen extends ConsumerWidget {
  const ActorScreen({super.key, required this.personId});

  static const name = 'actor-screen';

  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(actorDetailsProvider(personId));
    final creditsAsync = ref.watch(actorMovieCreditsProvider(personId));

    return detailsAsync.when(
      loading: () => const Scaffold(body: ActorDetailsSkeleton()),
      error: (error, _) => _buildErrorScaffold(context, ref),
      data: (details) {
        return Scaffold(
          body: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              _ActorSliverAppBar(details: details),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _ActorHeader(details: details),
                        if (details.biography.trim().isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _ActorBiography(details: details),
                        ],
                        const SizedBox(height: 16),
                        _ActorFacts(details: details),
                        const SizedBox(height: 16),
                        creditsAsync.when(
                          data: (credits) =>
                              _ActorFilmography(credits: credits),
                          loading: () => const SizedBox(
                            height: 120,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (error, _) {
                            LoggerFactory.warning(
                              'No se pudo cargar la filmografía de $personId: $error',
                            );
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorScaffold(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Error al cargar actor')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, size: 64, color: colors.error),
              const SizedBox(height: 16),
              Text(
                'No pudimos cargar el perfil',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Verifica tu conexión a internet e intenta de nuevo.',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(actorDetailsProvider(personId));
                      ref.invalidate(actorMovieCreditsProvider(personId));
                    },
                    child: const Text('Reintentar'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorSliverAppBar extends StatelessWidget {
  const _ActorSliverAppBar({required this.details});

  final ActorDetails details;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final photoUrl = resolvePosterUrl(details.profilePath, size: 'w780');

    return SliverAppBar(
      backgroundColor: Colors.black,
      expandedHeight: size.height * 0.55,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(bottom: 0),
        title: _GradientFill(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.7, 1.0],
          colors: [Colors.transparent, scaffoldBackgroundColor],
        ),
        background: Stack(
          children: [
            SizedBox.expand(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress != null) return const SizedBox();
                  return FadeIn(child: child);
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade900,
                    child: Icon(
                      Icons.person,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  );
                },
              ),
            ),
            const _GradientFill(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.25],
              colors: [Colors.black87, Colors.transparent],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientFill extends StatelessWidget {
  const _GradientFill({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    required this.stops,
    required this.colors,
  });

  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<double> stops;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            stops: stops,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _ActorHeader extends StatelessWidget {
  const _ActorHeader({required this.details});

  final ActorDetails details;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.name,
                      style: textStyles.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (details.knownForDepartment.isNotEmpty)
                      Text(
                        details.knownForDepartment,
                        style: textStyles.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      details.popularity.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (details.birthday != null && details.birthday!.isNotEmpty)
                _FactChip(
                  icon: Icons.cake,
                  label: _formatBirthday(details.birthday!),
                ),
              if (details.placeOfBirth != null &&
                  details.placeOfBirth!.isNotEmpty)
                _FactChip(icon: Icons.place, label: details.placeOfBirth!),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBirthday(String birthday) {
    final age = _calculateAge(birthday);
    if (age == null) return birthday;
    return '$birthday · $age años';
  }

  int? _calculateAge(String birthday) {
    try {
      final birth = DateTime.parse(birthday);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }
}

class _ActorFacts extends StatelessWidget {
  const _ActorFacts({required this.details});

  final ActorDetails details;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    final isDeceased = details.deathday != null && details.deathday!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Datos',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (details.knownForDepartment.isNotEmpty)
            _FactRow(
              role: 'Departamento',
              value: details.knownForDepartment,
              icon: Icons.work,
            ),
          if (details.placeOfBirth != null &&
              details.placeOfBirth!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FactRow(
              role: 'Lugar de nacimiento',
              value: details.placeOfBirth!,
              icon: Icons.place,
            ),
          ],
          const SizedBox(height: 8),
          _FactRow(
            role: 'Estado',
            value: isDeceased ? 'Fallecido (${details.deathday})' : 'En activo',
            icon: isDeceased ? Icons.history : Icons.favorite,
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.role, required this.value, required this.icon});

  final String role;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: textStyles.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: textStyles.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActorBiography extends StatefulWidget {
  const _ActorBiography({required this.details});

  final ActorDetails details;

  @override
  State<_ActorBiography> createState() => _ActorBiographyState();
}

class _ActorBiographyState extends State<_ActorBiography> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final biography = widget.details.biography;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Biografía',
                style: textStyles.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              biography.length > 150
                  ? '${biography.substring(0, 150)}...'
                  : biography,
              style: textStyles.bodyMedium?.copyWith(height: 1.5),
            ),
            secondChild: Text(
              biography,
              style: textStyles.bodyMedium?.copyWith(height: 1.5),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          if (biography.length > 150)
            TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(
                _isExpanded ? 'Ver menos' : 'Ver más',
                style: TextStyle(color: colors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActorFilmography extends StatelessWidget {
  const _ActorFilmography({required this.credits});

  final List<ActorMovieCredit> credits;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    if (credits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.movie, color: colors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'Filmografía',
              style: textStyles.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${credits.length}',
                style: textStyles.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.58,
          ),
          itemCount: credits.length,
          itemBuilder: (context, index) {
            final credit = credits[index];
            return _FilmographyCard(credit: credit);
          },
        ),
      ],
    );
  }
}

class _FilmographyCard extends StatelessWidget {
  const _FilmographyCard({required this.credit});

  final ActorMovieCredit credit;

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/movie/${credit.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                resolvePosterUrl(credit.posterPath, size: 'w185'),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.movie,
                    size: 40,
                    color: colors.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            credit.title,
            style: textStyles.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (credit.character != null && credit.character!.isNotEmpty)
            Text(
              credit.character!,
              style: textStyles.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.6),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
