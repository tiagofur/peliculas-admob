import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_theme.dart' as app_theme;
import '../providers/theme/theme_provider.dart';

/// Widget de demostración para mostrar las capacidades del sistema de temas
/// Útil para testing manual y presentación de funcionalidades
class ThemeShowcaseWidget extends ConsumerWidget {
  const ThemeShowcaseWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final colorList = ref.watch(colorListProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demostración de Temas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: () {
              _showThemeBottomSheet(context, ref);
            },
            tooltip: 'Cambiar tema',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado actual del tema
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado Actual del Tema',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Modo', 
                      _getThemeModeText(themeState.themeMode),
                      _getThemeModeIcon(themeState.themeMode),
                    ),
                    _buildInfoRow(
                      'Color', 
                      'Color ${themeState.selectedColor + 1}',
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colorList[themeState.selectedColor],
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    _buildInfoRow(
                      'Brillo detectado', 
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark 
                        ? 'Oscuro' : 'Claro',
                      Icon(MediaQuery.platformBrightnessOf(context) == Brightness.dark 
                        ? Icons.nights_stay : Icons.wb_sunny),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Controles rápidos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Controles Rápidos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildThemeChip(
                          context, 
                          ref, 
                          'Sistema', 
                          app_theme.ThemeMode.system,
                          Icons.brightness_auto,
                        ),
                        _buildThemeChip(
                          context, 
                          ref, 
                          'Claro', 
                          app_theme.ThemeMode.light,
                          Icons.light_mode,
                        ),
                        _buildThemeChip(
                          context, 
                          ref, 
                          'Oscuro', 
                          app_theme.ThemeMode.dark,
                          Icons.dark_mode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selector de colores
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colores de Tema',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: List.generate(
                        colorList.length,
                        (index) => _buildColorChip(context, ref, index, colorList[index]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Widget icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          icon,
          const SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildThemeChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    app_theme.ThemeMode mode,
    IconData icon,
  ) {
    final themeState = ref.watch(themeNotifierProvider);
    final isSelected = themeState.themeMode == mode;
    
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(icon, size: 18),
      onSelected: (selected) {
        if (selected) {
          ref.read(themeNotifierProvider.notifier).setThemeMode(mode);
        }
      },
    );
  }

  Widget _buildColorChip(BuildContext context, WidgetRef ref, int index, Color color) {
    final themeState = ref.watch(themeNotifierProvider);
    final isSelected = themeState.selectedColor == index;
    
    return GestureDetector(
      onTap: () {
        ref.read(themeNotifierProvider.notifier).changeColorIndex(index);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
          ? Icon(
              Icons.check,
              color: _getContrastColor(color),
              size: 24,
            )
          : null,
      ),
    );
  }

  String _getThemeModeText(app_theme.ThemeMode mode) {
    switch (mode) {
      case app_theme.ThemeMode.system:
        return 'Sistema';
      case app_theme.ThemeMode.light:
        return 'Claro';
      case app_theme.ThemeMode.dark:
        return 'Oscuro';
    }
  }

  IconData _getThemeModeIcon(app_theme.ThemeMode mode) {
    switch (mode) {
      case app_theme.ThemeMode.system:
        return Icons.brightness_auto;
      case app_theme.ThemeMode.light:
        return Icons.light_mode;
      case app_theme.ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  void _showThemeBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración Rápida de Tema',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Esta es una demostración del sistema de temas mejorado.'),
            const SizedBox(height: 8),
            Text('• Soporte para modo sistema automático'),
            Text('• Temas claro y oscuro manuales'),
            Text('• 6 colores de tema personalizables'),
            Text('• Persistencia de configuración'),
            Text('• Integración completa con Material 3'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}