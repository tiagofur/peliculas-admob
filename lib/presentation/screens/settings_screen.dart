import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_theme.dart' as app_theme;
import '../providers/theme/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final colorList = ref.watch(colorListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
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
                        'Apariencia',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Selector de modo de tema
                  Text(
                    'Modo de tema',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildThemeModeSelector(context, ref, themeState),
                  
                  const SizedBox(height: 24),
                  
                  // Selector de color
                  Text(
                    'Color del tema',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildColorSelector(context, ref, colorList, themeState),
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
                        'Información',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'El modo "Sistema" seguirá automáticamente la configuración de tema de tu dispositivo.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
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

  Widget _buildThemeModeSelector(BuildContext context, WidgetRef ref, ThemeState themeState) {
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
          title: const Text('Sistema'),
          subtitle: const Text('Seguir la configuración del dispositivo'),
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
          title: const Text('Claro'),
          subtitle: const Text('Tema con colores claros'),
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
          title: const Text('Oscuro'),
          subtitle: const Text('Tema con colores oscuros'),
          secondary: const Icon(Icons.dark_mode),
        ),
      ],
    );
  }

  Widget _buildColorSelector(BuildContext context, WidgetRef ref, List<Color> colorList, ThemeState themeState) {
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
                ref.read(themeNotifierProvider.notifier).changeColorIndex(index);
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
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
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