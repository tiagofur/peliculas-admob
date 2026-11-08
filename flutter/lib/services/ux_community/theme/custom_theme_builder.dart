// lib/services/ux_community/theme/custom_theme_builder.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'advanced_theme_manager.dart';

class ColorHarmony {
  static List<Color> complementary(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    final complementHue = (hsl.hue + 180) % 360;
    return [
      baseColor,
      hsl.withHue(complementHue).toColor(),
    ];
  }

  static List<Color> triadic(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    return [
      baseColor,
      hsl.withHue((hsl.hue + 120) % 360).toColor(),
      hsl.withHue((hsl.hue + 240) % 360).toColor(),
    ];
  }

  static List<Color> analogous(Color baseColor, {int count = 5}) {
    final hsl = HSLColor.fromColor(baseColor);
    final colors = <Color>[];
    const step = 30.0; // 30 degrees apart

    for (int i = 0; i < count; i++) {
      final hue = (hsl.hue + (i * step)) % 360;
      colors.add(hsl.withHue(hue).toColor());
    }

    return colors;
  }

  static List<Color> monochromatic(Color baseColor, {int count = 5}) {
    final hsl = HSLColor.fromColor(baseColor);
    final colors = <Color>[];

    for (int i = 0; i < count; i++) {
      final lightness = (0.2 + (i * 0.15)).clamp(0.1, 0.9);
      colors.add(hsl.withLightness(lightness).toColor());
    }

    return colors;
  }

  static List<Color> tetradic(Color baseColor) {
    final hsl = HSLColor.fromColor(baseColor);
    return [
      baseColor,
      hsl.withHue((hsl.hue + 90) % 360).toColor(),
      hsl.withHue((hsl.hue + 180) % 360).toColor(),
      hsl.withHue((hsl.hue + 270) % 360).toColor(),
    ];
  }
}

class ColorPaletteGenerator {
  static ColorScheme generateFromSeed({
    required Color seedColor,
    required Brightness brightness,
    ColorHarmonyType harmonyType = ColorHarmonyType.material,
  }) {
    switch (harmonyType) {
      case ColorHarmonyType.material:
        return ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        );
      case ColorHarmonyType.complementary:
        return _generateComplementaryScheme(seedColor, brightness);
      case ColorHarmonyType.triadic:
        return _generateTriadicScheme(seedColor, brightness);
      case ColorHarmonyType.analogous:
        return _generateAnalogousScheme(seedColor, brightness);
      case ColorHarmonyType.monochromatic:
        return _generateMonochromaticScheme(seedColor, brightness);
      case ColorHarmonyType.tetradic:
        return _generateTetradicScheme(seedColor, brightness);
    }
  }

  static ColorScheme _generateComplementaryScheme(
      Color seed, Brightness brightness) {
    final colors = ColorHarmony.complementary(seed);
    final baseScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return baseScheme.copyWith(
      secondary: colors[1],
      secondaryContainer: _adjustForContainer(colors[1], brightness),
    );
  }

  static ColorScheme _generateTriadicScheme(Color seed, Brightness brightness) {
    final colors = ColorHarmony.triadic(seed);
    final baseScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return baseScheme.copyWith(
      secondary: colors[1],
      secondaryContainer: _adjustForContainer(colors[1], brightness),
      tertiary: colors[2],
      tertiaryContainer: _adjustForContainer(colors[2], brightness),
    );
  }

  static ColorScheme _generateAnalogousScheme(
      Color seed, Brightness brightness) {
    final colors = ColorHarmony.analogous(seed);
    final baseScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return baseScheme.copyWith(
      secondary: colors[1],
      secondaryContainer: _adjustForContainer(colors[1], brightness),
      tertiary: colors[2],
      tertiaryContainer: _adjustForContainer(colors[2], brightness),
    );
  }

  static ColorScheme _generateMonochromaticScheme(
      Color seed, Brightness brightness) {
    final colors = ColorHarmony.monochromatic(seed);
    final baseScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return baseScheme.copyWith(
      primary: colors[2], // Middle tone
      primaryContainer: _adjustForContainer(colors[2], brightness),
      secondary: colors[1],
      secondaryContainer: _adjustForContainer(colors[1], brightness),
    );
  }

  static ColorScheme _generateTetradicScheme(
      Color seed, Brightness brightness) {
    final colors = ColorHarmony.tetradic(seed);
    final baseScheme =
        ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    return baseScheme.copyWith(
      secondary: colors[1],
      secondaryContainer: _adjustForContainer(colors[1], brightness),
      tertiary: colors[2],
      tertiaryContainer: _adjustForContainer(colors[2], brightness),
    );
  }

  static Color _adjustForContainer(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    if (brightness == Brightness.light) {
      return hsl.withLightness(math.min(hsl.lightness + 0.3, 0.9)).toColor();
    } else {
      return hsl.withLightness(math.max(hsl.lightness - 0.3, 0.1)).toColor();
    }
  }
}

enum ColorHarmonyType {
  material,
  complementary,
  triadic,
  analogous,
  monochromatic,
  tetradic,
}

enum ThemeStyle {
  minimal,
  vibrant,
  elegant,
  playful,
  professional,
  cinematic,
}

class CustomThemeBuilder {
  static CustomTheme buildFromColors({
    required String name,
    required Color primaryColor,
    Color? secondaryColor,
    ColorHarmonyType harmonyType = ColorHarmonyType.material,
    ThemeStyle style = ThemeStyle.minimal,
    Map<String, dynamic> customProperties = const {},
  }) {
    final lightScheme = ColorPaletteGenerator.generateFromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      harmonyType: harmonyType,
    );

    final darkScheme = ColorPaletteGenerator.generateFromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      harmonyType: harmonyType,
    );

    // Apply style modifications
    final styledLightScheme = _applyStyle(lightScheme, style, Brightness.light);
    final styledDarkScheme = _applyStyle(darkScheme, style, Brightness.dark);

    return CustomTheme(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      lightColorScheme: styledLightScheme,
      darkColorScheme: styledDarkScheme,
      textTheme: _buildTextThemeForStyle(style),
      customProperties: {
        'harmonyType': harmonyType.toString(),
        'style': style.toString(),
        'primaryColor': primaryColor.toARGB32(),
        'secondaryColor': secondaryColor?.toARGB32(),
        ...customProperties,
      },
      createdAt: DateTime.now(),
      isUserCreated: true,
    );
  }

  static CustomTheme buildFromImage({
    required String name,
    required List<Color> dominantColors,
    ThemeStyle style = ThemeStyle.minimal,
    Map<String, dynamic> customProperties = const {},
  }) {
    if (dominantColors.isEmpty) {
      throw ArgumentError('At least one dominant color is required');
    }

    final primaryColor = dominantColors.first;
    final secondaryColor = dominantColors.length > 1 ? dominantColors[1] : null;

    return buildFromColors(
      name: name,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      harmonyType: ColorHarmonyType.material,
      style: style,
      customProperties: {
        'sourceType': 'image',
        'dominantColors': dominantColors.map((c) => c.toARGB32()).toList(),
        ...customProperties,
      },
    );
  }

  static CustomTheme buildCinematicTheme({
    required String name,
    CinematicPalette palette = CinematicPalette.darkDrama,
    Map<String, dynamic> customProperties = const {},
  }) {
    final colors = _getCinematicColors(palette);

    return buildFromColors(
      name: name,
      primaryColor: colors['primary']!,
      secondaryColor: colors['secondary'],
      style: ThemeStyle.cinematic,
      customProperties: {
        'cinematicPalette': palette.toString(),
        'sourceType': 'cinematic',
        ...customProperties,
      },
    );
  }

  static CustomTheme buildMovieGenreTheme({
    required String name,
    required MovieGenre genre,
    Map<String, dynamic> customProperties = const {},
  }) {
    final colors = _getGenreColors(genre);
    final style = _getGenreStyle(genre);

    return buildFromColors(
      name: name,
      primaryColor: colors['primary']!,
      secondaryColor: colors['secondary'],
      style: style,
      harmonyType: ColorHarmonyType.triadic,
      customProperties: {
        'genre': genre.toString(),
        'sourceType': 'genre',
        ...customProperties,
      },
    );
  }

  static ColorScheme _applyStyle(
      ColorScheme scheme, ThemeStyle style, Brightness brightness) {
    switch (style) {
      case ThemeStyle.minimal:
        return _applyMinimalStyle(scheme, brightness);
      case ThemeStyle.vibrant:
        return _applyVibrantStyle(scheme, brightness);
      case ThemeStyle.elegant:
        return _applyElegantStyle(scheme, brightness);
      case ThemeStyle.playful:
        return _applyPlayfulStyle(scheme, brightness);
      case ThemeStyle.professional:
        return _applyProfessionalStyle(scheme, brightness);
      case ThemeStyle.cinematic:
        return _applyCinematicStyle(scheme, brightness);
    }
  }

  static ColorScheme _applyMinimalStyle(
      ColorScheme scheme, Brightness brightness) {
    // Reduce saturation for minimal look
    return scheme.copyWith(
      primary: _desaturate(scheme.primary, 0.2),
      secondary: _desaturate(scheme.secondary, 0.3),
      surface: brightness == Brightness.light
          ? const Color(0xFFFFFFFE)
          : const Color(0xFF121212),
    );
  }

  static ColorScheme _applyVibrantStyle(
      ColorScheme scheme, Brightness brightness) {
    // Increase saturation and adjust contrast
    return scheme.copyWith(
      primary: _saturate(scheme.primary, 0.3),
      secondary: _saturate(scheme.secondary, 0.2),
      tertiary: _saturate(scheme.tertiary, 0.25),
    );
  }

  static ColorScheme _applyElegantStyle(
      ColorScheme scheme, Brightness brightness) {
    // Sophisticated, muted tones
    return scheme.copyWith(
      primary: _adjustBrightness(
          scheme.primary, brightness == Brightness.light ? -0.1 : 0.1),
      secondary: _desaturate(scheme.secondary, 0.15),
      surface: brightness == Brightness.light
          ? const Color(0xFFF8F8F8)
          : const Color(0xFF1A1A1A),
    );
  }

  static ColorScheme _applyPlayfulStyle(
      ColorScheme scheme, Brightness brightness) {
    // Bright, fun colors
    return scheme.copyWith(
      primary: _saturate(scheme.primary, 0.4),
      secondary: _saturate(scheme.secondary, 0.3),
      tertiary: _saturate(scheme.tertiary, 0.35),
      primaryContainer: _lighten(scheme.primaryContainer, 0.1),
    );
  }

  static ColorScheme _applyProfessionalStyle(
      ColorScheme scheme, Brightness brightness) {
    // Corporate, trustworthy colors
    return scheme.copyWith(
      primary: _desaturate(scheme.primary, 0.25),
      secondary: _desaturate(scheme.secondary, 0.2),
      surface: brightness == Brightness.light
          ? const Color(0xFFFAFAFA)
          : const Color(0xFF0F0F0F),
    );
  }

  static ColorScheme _applyCinematicStyle(
      ColorScheme scheme, Brightness brightness) {
    // Rich, dramatic colors inspired by film
    return scheme.copyWith(
      primary: _adjustBrightness(
          scheme.primary, brightness == Brightness.light ? -0.2 : 0.15),
      secondary: _saturate(scheme.secondary, 0.1),
      surface: brightness == Brightness.light
          ? const Color(0xFFF5F5F0)
          : const Color(0xFF0A0A0A),
    );
  }

  static TextTheme _buildTextThemeForStyle(ThemeStyle style) {
    // Return appropriate text theme based on style
    // For simplicity, returning default theme
    // In practice, you'd customize fonts, sizes, weights based on style
    return const TextTheme();
  }

  static Map<String, Color> _getCinematicColors(CinematicPalette palette) {
    switch (palette) {
      case CinematicPalette.darkDrama:
        return {
          'primary': const Color(0xFF2C3E50),
          'secondary': const Color(0xFF8B4513),
        };
      case CinematicPalette.sciFi:
        return {
          'primary': const Color(0xFF00BFFF),
          'secondary': const Color(0xFF9400D3),
        };
      case CinematicPalette.horror:
        return {
          'primary': const Color(0xFF8B0000),
          'secondary': const Color(0xFF2F4F4F),
        };
      case CinematicPalette.romance:
        return {
          'primary': const Color(0xFFFF69B4),
          'secondary': const Color(0xFFDDA0DD),
        };
      case CinematicPalette.action:
        return {
          'primary': const Color(0xFFFF4500),
          'secondary': const Color(0xFF000000),
        };
      case CinematicPalette.comedy:
        return {
          'primary': const Color(0xFFFFD700),
          'secondary': const Color(0xFF32CD32),
        };
    }
  }

  static Map<String, Color> _getGenreColors(MovieGenre genre) {
    switch (genre) {
      case MovieGenre.action:
        return {
          'primary': Colors.red.shade700,
          'secondary': Colors.orange.shade600
        };
      case MovieGenre.comedy:
        return {
          'primary': Colors.amber.shade600,
          'secondary': Colors.lime.shade500
        };
      case MovieGenre.drama:
        return {
          'primary': Colors.indigo.shade700,
          'secondary': Colors.blueGrey.shade600
        };
      case MovieGenre.horror:
        return {
          'primary': Colors.grey.shade800,
          'secondary': Colors.red.shade900
        };
      case MovieGenre.romance:
        return {
          'primary': Colors.pink.shade400,
          'secondary': Colors.purple.shade300
        };
      case MovieGenre.sciFi:
        return {
          'primary': Colors.cyan.shade600,
          'secondary': Colors.blue.shade700
        };
      case MovieGenre.thriller:
        return {
          'primary': Colors.blueGrey.shade800,
          'secondary': Colors.grey.shade700
        };
      case MovieGenre.animation:
        return {
          'primary': Colors.purple.shade500,
          'secondary': Colors.teal.shade400
        };
    }
  }

  static ThemeStyle _getGenreStyle(MovieGenre genre) {
    switch (genre) {
      case MovieGenre.action:
        return ThemeStyle.vibrant;
      case MovieGenre.comedy:
        return ThemeStyle.playful;
      case MovieGenre.drama:
        return ThemeStyle.elegant;
      case MovieGenre.horror:
        return ThemeStyle.cinematic;
      case MovieGenre.romance:
        return ThemeStyle.elegant;
      case MovieGenre.sciFi:
        return ThemeStyle.minimal;
      case MovieGenre.thriller:
        return ThemeStyle.professional;
      case MovieGenre.animation:
        return ThemeStyle.playful;
    }
  }

  // Color manipulation utilities
  static Color _saturate(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(math.min(hsl.saturation + amount, 1.0)).toColor();
  }

  static Color _desaturate(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation(math.max(hsl.saturation - amount, 0.0)).toColor();
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(math.min(hsl.lightness + amount, 1.0)).toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(math.max(hsl.lightness - amount, 0.0)).toColor();
  }

  static Color _adjustBrightness(Color color, double amount) {
    return amount > 0 ? _lighten(color, amount) : _darken(color, -amount);
  }

  // Preset theme generators
  static List<CustomTheme> generatePresetThemes() {
    final presets = <CustomTheme>[];

    // Genre-based themes
    for (final genre in MovieGenre.values) {
      presets.add(buildMovieGenreTheme(
        name: '${_genreDisplayName(genre)} Theme',
        genre: genre,
      ));
    }

    // Cinematic themes
    for (final palette in CinematicPalette.values) {
      presets.add(buildCinematicTheme(
        name: '${_paletteDisplayName(palette)} Cinema',
        palette: palette,
      ));
    }

    // Popular color combinations
    presets.addAll([
      buildFromColors(
        name: 'Ocean Breeze',
        primaryColor: const Color(0xFF006A6B),
        secondaryColor: const Color(0xFF0096C7),
        style: ThemeStyle.minimal,
      ),
      buildFromColors(
        name: 'Sunset Vibes',
        primaryColor: const Color(0xFFFF6B6B),
        secondaryColor: const Color(0xFFFFD93D),
        style: ThemeStyle.vibrant,
      ),
      buildFromColors(
        name: 'Forest Zen',
        primaryColor: const Color(0xFF2D5016),
        secondaryColor: const Color(0xFF68B984),
        style: ThemeStyle.elegant,
      ),
    ]);

    return presets;
  }

  static String _genreDisplayName(MovieGenre genre) {
    return genre
        .toString()
        .split('.')
        .last
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .trim();
  }

  static String _paletteDisplayName(CinematicPalette palette) {
    return palette
        .toString()
        .split('.')
        .last
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .trim();
  }
}

enum CinematicPalette {
  darkDrama,
  sciFi,
  horror,
  romance,
  action,
  comedy,
}

enum MovieGenre {
  action,
  comedy,
  drama,
  horror,
  romance,
  sciFi,
  thriller,
  animation,
}
