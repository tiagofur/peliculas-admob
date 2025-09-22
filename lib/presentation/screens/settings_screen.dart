import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_theme.dart' as app_theme;
import '../../l10n/app_localizations.dart';
import '../providers/locale/locale_provider.dart';
import '../providers/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final colorList = ref.watch(colorListProvider);
    final localeState = ref.watch(localeNotifierProvider);
    final l10n = AppLocalizations.of(context);

    if (l10n == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Sección de Idioma
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.language,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.language,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector de idioma
                  Text(
                    l10n.selectLanguage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageSelector(context, ref, localeState, l10n),

                  const SizedBox(height: 16),
                  Text(
                    l10n.languageDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(204), // 0.8 alpha
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sección de Tema
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.appearance,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector de modo de tema
                  Text(
                    l10n.themeMode,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildThemeModeSelector(context, ref, themeState, l10n),

                  const SizedBox(height: 24),

                  // Selector de color
                  Text(
                    l10n.themeColor,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildColorSelector(context, ref, colorList, themeState),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sección de Notificaciones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Notificaciones',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Permisos de Recordatorios'),
                    subtitle: const Text(
                        'Configura permisos para alarmas y recordatorios'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      context.push('/settings/notifications-permissions');
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Información adicional
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.information,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.systemThemeDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha(204), // 0.8 alpha
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeSelector(BuildContext context, WidgetRef ref,
      ThemeState themeState, AppLocalizations l10n) {
    return Column(
      children: [
        RadioListTile<app_theme.ThemeMode>(
          value: app_theme.ThemeMode.system,
          groupValue: themeState.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeNotifierProvider.notifier).setThemeMode(value);
            }
          },
          title: Text(l10n.system),
          subtitle: Text(l10n.systemThemeSubtitle),
          secondary: const Icon(Icons.brightness_auto),
        ),
        RadioListTile<app_theme.ThemeMode>(
          value: app_theme.ThemeMode.light,
          groupValue: themeState.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeNotifierProvider.notifier).setThemeMode(value);
            }
          },
          title: Text(l10n.light),
          subtitle: Text(l10n.lightThemeSubtitle),
          secondary: const Icon(Icons.light_mode),
        ),
        RadioListTile<app_theme.ThemeMode>(
          value: app_theme.ThemeMode.dark,
          groupValue: themeState.themeMode,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeNotifierProvider.notifier).setThemeMode(value);
            }
          },
          title: Text(l10n.dark),
          subtitle: Text(l10n.darkThemeSubtitle),
          secondary: const Icon(Icons.dark_mode),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context, WidgetRef ref,
      LocaleState localeState, AppLocalizations l10n) {
    final localeNotifier = ref.read(localeNotifierProvider.notifier);
    final currentLocale = localeState.locale ??
        Locale(Localizations.localeOf(context).languageCode);

    return Column(
      children: [
        RadioListTile<String>(
          value: 'es',
          groupValue: currentLocale.languageCode,
          onChanged: (value) {
            if (value != null) {
              localeNotifier.setLocale(Locale(value));
            }
          },
          title: Text(l10n.spanish),
          secondary: const Icon(Icons.language),
        ),
        RadioListTile<String>(
          value: 'en',
          groupValue: currentLocale.languageCode,
          onChanged: (value) {
            if (value != null) {
              localeNotifier.setLocale(Locale(value));
            }
          },
          title: Text(l10n.english),
          secondary: const Icon(Icons.language),
        ),
        RadioListTile<String>(
          value: 'pt',
          groupValue: currentLocale.languageCode,
          onChanged: (value) {
            if (value != null) {
              localeNotifier.setLocale(Locale(value));
            }
          },
          title: Text(l10n.portuguese),
          secondary: const Icon(Icons.language),
        ),
      ],
    );
  }

  Widget _buildColorSelector(BuildContext context, WidgetRef ref,
      List<Color> colorList, ThemeState themeState) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colorList.length,
        itemBuilder: (context, index) {
          final color = colorList[index];
          final isSelected = themeState.selectedColor == index;

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                ref
                    .read(themeNotifierProvider.notifier)
                    .changeColorIndex(index);
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 3,
                        )
                      : Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withAlpha(77), // 0.3 alpha
                          width: 1,
                        ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withAlpha(102), // 0.4 alpha
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: _getContrastColor(color),
                        size: 28,
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getContrastColor(Color color) {
    // Calcular si el color es claro u oscuro para usar el color de contraste apropiado
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
