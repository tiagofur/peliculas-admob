// lib/services/ux_community/ux_components/advanced_ux_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum AnimationIntensity {
  minimal,
  subtle,
  normal,
  enhanced,
  maximum,
}

enum GestureType {
  tap,
  doubleTap,
  longPress,
  swipeLeft,
  swipeRight,
  swipeUp,
  swipeDown,
  pinch,
  zoom,
  rotate,
  pan,
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}

enum MicroInteractionType {
  buttonPress,
  cardSelection,
  listScroll,
  tabSwitch,
  modalOpen,
  modalClose,
  loading,
  success,
  error,
  notification,
}

class UXPreferences {
  const UXPreferences({
    required this.userId,
    this.animationIntensity = AnimationIntensity.normal,
    this.enableHapticFeedback = true,
    this.enableSoundEffects = true,
    this.enableMicroInteractions = true,
    this.enableContextualAnimations = true,
    this.enableGestureShortcuts = true,
    this.enableAdaptiveUI = true,
    this.animationSpeed = 1.0,
    this.featureToggles = const {},
    this.customSettings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory UXPreferences.fromJson(Map<String, dynamic> json) {
    return UXPreferences(
      userId: json['userId'],
      animationIntensity: AnimationIntensity.values.firstWhere(
        (e) => e.toString() == json['animationIntensity'],
        orElse: () => AnimationIntensity.normal,
      ),
      enableHapticFeedback: json['enableHapticFeedback'] ?? true,
      enableSoundEffects: json['enableSoundEffects'] ?? true,
      enableMicroInteractions: json['enableMicroInteractions'] ?? true,
      enableContextualAnimations: json['enableContextualAnimations'] ?? true,
      enableGestureShortcuts: json['enableGestureShortcuts'] ?? true,
      enableAdaptiveUI: json['enableAdaptiveUI'] ?? true,
      animationSpeed: json['animationSpeed']?.toDouble() ?? 1.0,
      featureToggles: Map<String, bool>.from(json['featureToggles'] ?? {}),
      customSettings: Map<String, dynamic>.from(json['customSettings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  final String userId;
  final AnimationIntensity animationIntensity;
  final bool enableHapticFeedback;
  final bool enableSoundEffects;
  final bool enableMicroInteractions;
  final bool enableContextualAnimations;
  final bool enableGestureShortcuts;
  final bool enableAdaptiveUI;
  final double animationSpeed;
  final Map<String, bool> featureToggles;
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  UXPreferences copyWith({
    String? userId,
    AnimationIntensity? animationIntensity,
    bool? enableHapticFeedback,
    bool? enableSoundEffects,
    bool? enableMicroInteractions,
    bool? enableContextualAnimations,
    bool? enableGestureShortcuts,
    bool? enableAdaptiveUI,
    double? animationSpeed,
    Map<String, bool>? featureToggles,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UXPreferences(
      userId: userId ?? this.userId,
      animationIntensity: animationIntensity ?? this.animationIntensity,
      enableHapticFeedback: enableHapticFeedback ?? this.enableHapticFeedback,
      enableSoundEffects: enableSoundEffects ?? this.enableSoundEffects,
      enableMicroInteractions:
          enableMicroInteractions ?? this.enableMicroInteractions,
      enableContextualAnimations:
          enableContextualAnimations ?? this.enableContextualAnimations,
      enableGestureShortcuts:
          enableGestureShortcuts ?? this.enableGestureShortcuts,
      enableAdaptiveUI: enableAdaptiveUI ?? this.enableAdaptiveUI,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      featureToggles: featureToggles ?? this.featureToggles,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'animationIntensity': animationIntensity.toString(),
      'enableHapticFeedback': enableHapticFeedback,
      'enableSoundEffects': enableSoundEffects,
      'enableMicroInteractions': enableMicroInteractions,
      'enableContextualAnimations': enableContextualAnimations,
      'enableGestureShortcuts': enableGestureShortcuts,
      'enableAdaptiveUI': enableAdaptiveUI,
      'animationSpeed': animationSpeed,
      'featureToggles': featureToggles,
      'customSettings': customSettings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class GestureShortcut {
  const GestureShortcut({
    required this.id,
    required this.name,
    required this.description,
    required this.gesture,
    required this.action,
    this.parameters = const {},
    this.isActive = true,
    required this.createdAt,
  });

  factory GestureShortcut.fromJson(Map<String, dynamic> json) {
    return GestureShortcut(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      gesture: GestureType.values.firstWhere(
        (e) => e.toString() == json['gesture'],
        orElse: () => GestureType.tap,
      ),
      action: json['action'],
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
  final String id;
  final String name;
  final String description;
  final GestureType gesture;
  final String action;
  final Map<String, dynamic> parameters;
  final bool isActive;
  final DateTime createdAt;

  GestureShortcut copyWith({
    String? id,
    String? name,
    String? description,
    GestureType? gesture,
    String? action,
    Map<String, dynamic>? parameters,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return GestureShortcut(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      gesture: gesture ?? this.gesture,
      action: action ?? this.action,
      parameters: parameters ?? this.parameters,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'gesture': gesture.toString(),
      'action': action,
      'parameters': parameters,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AnimationProfile {
  const AnimationProfile({
    required this.id,
    required this.name,
    required this.intensity,
    this.durations = const {},
    this.curves = const {},
    this.customProperties = const {},
    this.isDefault = false,
  });

  factory AnimationProfile.fromJson(Map<String, dynamic> json) {
    return AnimationProfile(
      id: json['id'],
      name: json['name'],
      intensity: AnimationIntensity.values.firstWhere(
        (e) => e.toString() == json['intensity'],
        orElse: () => AnimationIntensity.normal,
      ),
      durations: Map<String, double>.from(json['durations'] ?? {}),
      curves: Map<String, String>.from(json['curves'] ?? {}),
      customProperties:
          Map<String, dynamic>.from(json['customProperties'] ?? {}),
      isDefault: json['isDefault'] ?? false,
    );
  }
  final String id;
  final String name;
  final AnimationIntensity intensity;
  final Map<String, double> durations;
  final Map<String, String> curves;
  final Map<String, dynamic> customProperties;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'intensity': intensity.toString(),
      'durations': durations,
      'curves': curves,
      'customProperties': customProperties,
      'isDefault': isDefault,
    };
  }
}

class MicroInteractionConfig {
  const MicroInteractionConfig({
    required this.type,
    required this.duration,
    this.curve = 'easeInOut',
    this.enableHaptic = true,
    this.hapticType,
    this.enableSound = false,
    this.soundAsset,
    this.animationProperties = const {},
  });

  factory MicroInteractionConfig.fromJson(Map<String, dynamic> json) {
    return MicroInteractionConfig(
      type: MicroInteractionType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MicroInteractionType.buttonPress,
      ),
      duration: Duration(milliseconds: json['duration'] ?? 200),
      curve: json['curve'] ?? 'easeInOut',
      enableHaptic: json['enableHaptic'] ?? true,
      hapticType: json['hapticType'] != null
          ? HapticType.values.firstWhere(
              (e) => e.toString() == json['hapticType'],
              orElse: () => HapticType.light,
            )
          : null,
      enableSound: json['enableSound'] ?? false,
      soundAsset: json['soundAsset'],
      animationProperties:
          Map<String, dynamic>.from(json['animationProperties'] ?? {}),
    );
  }
  final MicroInteractionType type;
  final Duration duration;
  final String curve;
  final bool enableHaptic;
  final HapticType? hapticType;
  final bool enableSound;
  final String? soundAsset;
  final Map<String, dynamic> animationProperties;

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'duration': duration.inMilliseconds,
      'curve': curve,
      'enableHaptic': enableHaptic,
      'hapticType': hapticType?.toString(),
      'enableSound': enableSound,
      'soundAsset': soundAsset,
      'animationProperties': animationProperties,
    };
  }
}

class ContextualAnimation {
  const ContextualAnimation({
    required this.id,
    required this.name,
    required this.trigger,
    this.conditions = const {},
    required this.animation,
    this.priority = 0,
    this.isActive = true,
  });

  factory ContextualAnimation.fromJson(Map<String, dynamic> json) {
    return ContextualAnimation(
      id: json['id'],
      name: json['name'],
      trigger: json['trigger'],
      conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
      animation: MicroInteractionConfig.fromJson(json['animation']),
      priority: json['priority'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }
  final String id;
  final String name;
  final String trigger;
  final Map<String, dynamic> conditions;
  final MicroInteractionConfig animation;
  final int priority;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'trigger': trigger,
      'conditions': conditions,
      'animation': animation.toJson(),
      'priority': priority,
      'isActive': isActive,
    };
  }
}

class AdaptiveUIConfig {
  const AdaptiveUIConfig({
    required this.deviceType,
    required this.screenSize,
    this.isDarkMode = false,
    this.isHighContrast = false,
    this.fontScale = 1.0,
    this.layoutAdjustments = const {},
    this.componentSizes = const {},
    this.spacingMultipliers = const {},
  });

  factory AdaptiveUIConfig.fromJson(Map<String, dynamic> json) {
    return AdaptiveUIConfig(
      deviceType: json['deviceType'],
      screenSize: json['screenSize'],
      isDarkMode: json['isDarkMode'] ?? false,
      isHighContrast: json['isHighContrast'] ?? false,
      fontScale: json['fontScale']?.toDouble() ?? 1.0,
      layoutAdjustments:
          Map<String, dynamic>.from(json['layoutAdjustments'] ?? {}),
      componentSizes: Map<String, dynamic>.from(json['componentSizes'] ?? {}),
      spacingMultipliers:
          Map<String, dynamic>.from(json['spacingMultipliers'] ?? {}),
    );
  }
  final String deviceType;
  final String screenSize;
  final bool isDarkMode;
  final bool isHighContrast;
  final double fontScale;
  final Map<String, dynamic> layoutAdjustments;
  final Map<String, dynamic> componentSizes;
  final Map<String, dynamic> spacingMultipliers;

  Map<String, dynamic> toJson() {
    return {
      'deviceType': deviceType,
      'screenSize': screenSize,
      'isDarkMode': isDarkMode,
      'isHighContrast': isHighContrast,
      'fontScale': fontScale,
      'layoutAdjustments': layoutAdjustments,
      'componentSizes': componentSizes,
      'spacingMultipliers': spacingMultipliers,
    };
  }
}

class AdvancedUXService {
  static const String _uxPreferencesKey = 'ux_preferences';
  static const String _gestureShortcutsKey = 'gesture_shortcuts';
  static const String _animationProfilesKey = 'animation_profiles';
  static const String _microInteractionsKey = 'micro_interactions';
  static const String _contextualAnimationsKey = 'contextual_animations';
  static const String _adaptiveConfigKey = 'adaptive_ui_config';

  SharedPreferences? _prefs;
  final Map<String, UXPreferences> _userPreferences = {};
  final Map<String, List<GestureShortcut>> _userGestureShortcuts =
      {}; // userId -> shortcuts
  final Map<String, AnimationProfile> _animationProfiles = {};
  final Map<MicroInteractionType, MicroInteractionConfig> _microInteractions =
      {};
  final Map<String, ContextualAnimation> _contextualAnimations = {};
  final Map<String, AdaptiveUIConfig> _adaptiveConfigs = {}; // userId -> config

  final StreamController<UXPreferences> _preferencesController =
      StreamController.broadcast();
  final StreamController<List<GestureShortcut>> _gesturesController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _animationController =
      StreamController.broadcast();
  final StreamController<AdaptiveUIConfig> _adaptiveController =
      StreamController.broadcast();

  // Getters
  Stream<UXPreferences> get preferencesStream => _preferencesController.stream;
  Stream<List<GestureShortcut>> get gesturesStream =>
      _gesturesController.stream;
  Stream<Map<String, dynamic>> get animationStream =>
      _animationController.stream;
  Stream<AdaptiveUIConfig> get adaptiveStream => _adaptiveController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadUXPreferences();
      await _loadGestureShortcuts();
      await _loadAnimationProfiles();
      await _loadMicroInteractions();
      await _loadContextualAnimations();
      await _loadAdaptiveConfigs();
      await _initializeDefaultConfigurations();
      LoggerFactory.info('AdvancedUXService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing AdvancedUXService: $e');
    }
  }

  // UX Preferences Management
  Future<void> updateUXPreferences(UXPreferences preferences) async {
    try {
      final updatedPreferences =
          preferences.copyWith(updatedAt: DateTime.now());
      _userPreferences[preferences.userId] = updatedPreferences;

      await _saveUXPreferences();
      _preferencesController.add(updatedPreferences);

      // Update adaptive configuration based on new preferences
      await _updateAdaptiveConfiguration(preferences.userId);

      LoggerFactory.info(
          'UX preferences updated for user ${preferences.userId}');
    } catch (e) {
      LoggerFactory.error('Error updating UX preferences: $e');
    }
  }

  UXPreferences getUserPreferences(String userId) {
    return _userPreferences[userId] ??
        UXPreferences(
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> setAnimationIntensity(
      String userId, AnimationIntensity intensity) async {
    final preferences = getUserPreferences(userId);
    await updateUXPreferences(
        preferences.copyWith(animationIntensity: intensity));
  }

  Future<void> setAnimationSpeed(String userId, double speed) async {
    final preferences = getUserPreferences(userId);
    await updateUXPreferences(
        preferences.copyWith(animationSpeed: speed.clamp(0.1, 3.0)));
  }

  Future<void> toggleFeature(
      String userId, String feature, bool enabled) async {
    final preferences = getUserPreferences(userId);

    final updatedPreferences = switch (feature) {
      'hapticFeedback' => preferences.copyWith(enableHapticFeedback: enabled),
      'soundEffects' => preferences.copyWith(enableSoundEffects: enabled),
      'microInteractions' =>
        preferences.copyWith(enableMicroInteractions: enabled),
      'contextualAnimations' =>
        preferences.copyWith(enableContextualAnimations: enabled),
      'gestureShortcuts' =>
        preferences.copyWith(enableGestureShortcuts: enabled),
      'adaptiveUI' => preferences.copyWith(enableAdaptiveUI: enabled),
      _ => preferences.copyWith(
          featureToggles: {
            ...preferences.featureToggles,
            feature: enabled,
          },
        ),
    };

    await updateUXPreferences(updatedPreferences);
  }

  bool isFeatureEnabled(String userId, String feature) {
    final preferences = getUserPreferences(userId);

    return switch (feature) {
      'hapticFeedback' => preferences.enableHapticFeedback,
      'soundEffects' => preferences.enableSoundEffects,
      'microInteractions' => preferences.enableMicroInteractions,
      'contextualAnimations' => preferences.enableContextualAnimations,
      'gestureShortcuts' => preferences.enableGestureShortcuts,
      'adaptiveUI' => preferences.enableAdaptiveUI,
      _ => preferences.featureToggles[feature] ?? true,
    };
  }

  // Haptic Feedback System
  Future<void> playHaptic(String userId, HapticType type) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableHapticFeedback) return;

      switch (type) {
        case HapticType.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticType.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticType.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case HapticType.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticType.success:
          await HapticFeedback.mediumImpact();
          break;
        case HapticType.warning:
          await HapticFeedback.lightImpact();
          break;
        case HapticType.error:
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      LoggerFactory.error('Error playing haptic feedback: $e');
    }
  }

  Future<void> playMicroInteractionHaptic(
      String userId, MicroInteractionType type) async {
    final config = _microInteractions[type];
    if (config != null && config.enableHaptic && config.hapticType != null) {
      await playHaptic(userId, config.hapticType!);
    }
  }

  // Gesture Shortcuts System
  Future<String?> createGestureShortcut({
    required String userId,
    required String name,
    required String description,
    required GestureType gesture,
    required String action,
    Map<String, dynamic> parameters = const {},
  }) async {
    try {
      final shortcutId = 'gesture_${DateTime.now().millisecondsSinceEpoch}';

      final shortcut = GestureShortcut(
        id: shortcutId,
        name: name,
        description: description,
        gesture: gesture,
        action: action,
        parameters: parameters,
        createdAt: DateTime.now(),
      );

      _userGestureShortcuts.putIfAbsent(userId, () => []);
      _userGestureShortcuts[userId]!.add(shortcut);

      await _saveGestureShortcuts();
      _gesturesController.add(_userGestureShortcuts[userId]!);

      LoggerFactory.info('Gesture shortcut created: $name for user $userId');
      return shortcutId;
    } catch (e) {
      LoggerFactory.error('Error creating gesture shortcut: $e');
      return null;
    }
  }

  Future<void> updateGestureShortcut(
      String userId, String shortcutId, GestureShortcut updatedShortcut) async {
    try {
      final shortcuts = _userGestureShortcuts[userId] ?? [];
      final index = shortcuts.indexWhere((s) => s.id == shortcutId);

      if (index >= 0) {
        shortcuts[index] = updatedShortcut;
        await _saveGestureShortcuts();
        _gesturesController.add(shortcuts);
      }
    } catch (e) {
      LoggerFactory.error('Error updating gesture shortcut: $e');
    }
  }

  Future<void> deleteGestureShortcut(String userId, String shortcutId) async {
    try {
      final shortcuts = _userGestureShortcuts[userId] ?? [];
      shortcuts.removeWhere((s) => s.id == shortcutId);

      await _saveGestureShortcuts();
      _gesturesController.add(shortcuts);
    } catch (e) {
      LoggerFactory.error('Error deleting gesture shortcut: $e');
    }
  }

  List<GestureShortcut> getUserGestureShortcuts(String userId) {
    return _userGestureShortcuts[userId] ?? [];
  }

  Future<bool> executeGestureAction(
      String userId, GestureType gesture, Map<String, dynamic> context) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableGestureShortcuts) return false;

      final shortcuts = getUserGestureShortcuts(userId);
      final matchingShortcut = shortcuts.firstWhere(
        (s) => s.gesture == gesture && s.isActive,
        orElse: () => GestureShortcut(
            id: '',
            name: '',
            description: '',
            gesture: gesture,
            action: '',
            createdAt: DateTime.now()),
      );

      if (matchingShortcut.id.isEmpty) return false;

      // Execute the action (this would be implemented based on your app's action system)
      await _executeAction(userId, matchingShortcut.action, {
        ...matchingShortcut.parameters,
        ...context,
      });

      LoggerFactory.info('Executed gesture action: ${matchingShortcut.action}');
      return true;
    } catch (e) {
      LoggerFactory.error('Error executing gesture action: $e');
      return false;
    }
  }

  Future<void> _executeAction(
      String userId, String action, Map<String, dynamic> parameters) async {
    // Mock implementation - in real app, this would integrate with your action system
    switch (action) {
      case 'navigate_home':
        LoggerFactory.debug('Navigate to home');
        break;
      case 'open_search':
        LoggerFactory.debug('Open search');
        break;
      case 'toggle_theme':
        LoggerFactory.debug('Toggle theme');
        break;
      case 'show_favorites':
        LoggerFactory.debug('Show favorites');
        break;
      default:
        LoggerFactory.warning('Unknown action: $action');
    }
  }

  // Animation System
  Future<void> createCustomAnimationProfile({
    required String name,
    required AnimationIntensity intensity,
    Map<String, double> durations = const {},
    Map<String, String> curves = const {},
  }) async {
    try {
      final profileId = 'profile_${DateTime.now().millisecondsSinceEpoch}';

      final profile = AnimationProfile(
        id: profileId,
        name: name,
        intensity: intensity,
        durations: durations,
        curves: curves,
      );

      _animationProfiles[profileId] = profile;
      await _saveAnimationProfiles();

      _animationController.add({
        'type': 'profile_created',
        'profileId': profileId,
        'profile': profile.toJson(),
      });

      LoggerFactory.info('Custom animation profile created: $name');
    } catch (e) {
      LoggerFactory.error('Error creating animation profile: $e');
    }
  }

  AnimationProfile? getAnimationProfile(String userId) {
    final preferences = getUserPreferences(userId);
    return _animationProfiles.values.firstWhere(
      (p) => p.intensity == preferences.animationIntensity && p.isDefault,
      orElse: () => _getDefaultAnimationProfile(preferences.animationIntensity),
    );
  }

  AnimationProfile _getDefaultAnimationProfile(AnimationIntensity intensity) {
    final baseDurations = <String, double>{};
    final curves = <String, String>{};

    switch (intensity) {
      case AnimationIntensity.minimal:
        baseDurations.addAll({
          'button_press': 50,
          'page_transition': 150,
          'modal_open': 100,
          'loading': 200,
        });
        curves.addAll({
          'default': 'linear',
          'bounce': 'easeOut',
        });
        break;
      case AnimationIntensity.subtle:
        baseDurations.addAll({
          'button_press': 100,
          'page_transition': 200,
          'modal_open': 150,
          'loading': 300,
        });
        curves.addAll({
          'default': 'easeInOut',
          'bounce': 'easeOutBack',
        });
        break;
      case AnimationIntensity.normal:
        baseDurations.addAll({
          'button_press': 150,
          'page_transition': 300,
          'modal_open': 250,
          'loading': 500,
        });
        curves.addAll({
          'default': 'easeInOutCubic',
          'bounce': 'elasticOut',
        });
        break;
      case AnimationIntensity.enhanced:
        baseDurations.addAll({
          'button_press': 200,
          'page_transition': 400,
          'modal_open': 350,
          'loading': 700,
        });
        curves.addAll({
          'default': 'easeInOutQuart',
          'bounce': 'bounceOut',
        });
        break;
      case AnimationIntensity.maximum:
        baseDurations.addAll({
          'button_press': 300,
          'page_transition': 600,
          'modal_open': 500,
          'loading': 1000,
        });
        curves.addAll({
          'default': 'easeInOutBack',
          'bounce': 'elasticOut',
        });
        break;
    }

    return AnimationProfile(
      id: 'default_$intensity',
      name: 'Default ${intensity.toString().split('.').last}',
      intensity: intensity,
      durations: baseDurations,
      curves: curves,
      isDefault: true,
    );
  }

  Duration getAnimationDuration(String userId, String animationType) {
    final profile = getAnimationProfile(userId);
    final preferences = getUserPreferences(userId);

    final baseDuration = profile?.durations[animationType] ?? 300.0;
    final adjustedDuration = baseDuration * preferences.animationSpeed;

    return Duration(milliseconds: adjustedDuration.round());
  }

  String getAnimationCurve(String userId, String curveType) {
    final profile = getAnimationProfile(userId);
    return profile?.curves[curveType] ?? 'easeInOut';
  }

  // Micro-interactions System
  Future<void> triggerMicroInteraction(String userId, MicroInteractionType type,
      [Map<String, dynamic>? context]) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableMicroInteractions) return;

      final config = _microInteractions[type];
      if (config == null) return;

      // Play haptic feedback
      if (config.enableHaptic && config.hapticType != null) {
        await playHaptic(userId, config.hapticType!);
      }

      // Play sound effect (if implemented)
      if (config.enableSound &&
          config.soundAsset != null &&
          preferences.enableSoundEffects) {
        await _playSoundEffect(config.soundAsset!);
      }

      // Trigger animation
      _animationController.add({
        'type': 'micro_interaction',
        'interactionType': type.toString(),
        'config': config.toJson(),
        'context': context ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      LoggerFactory.error('Error triggering micro-interaction: $e');
    }
  }

  Future<void> _playSoundEffect(String soundAsset) async {
    // Mock implementation - in real app, would use audio player
    LoggerFactory.debug('Playing sound effect: $soundAsset');
  }

  // Contextual Animations
  Future<void> registerContextualAnimation(
      ContextualAnimation animation) async {
    try {
      _contextualAnimations[animation.id] = animation;
      await _saveContextualAnimations();

      _animationController.add({
        'type': 'contextual_animation_registered',
        'animationId': animation.id,
        'animation': animation.toJson(),
      });
    } catch (e) {
      LoggerFactory.error('Error registering contextual animation: $e');
    }
  }

  Future<bool> shouldTriggerContextualAnimation(
      String userId, String trigger, Map<String, dynamic> context) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableContextualAnimations) return false;

      final animations = _contextualAnimations.values
          .where((a) => a.trigger == trigger && a.isActive)
          .toList();

      // Sort by priority
      animations.sort((a, b) => b.priority.compareTo(a.priority));

      for (final animation in animations) {
        if (_checkAnimationConditions(animation.conditions, context)) {
          await triggerMicroInteraction(
              userId, animation.animation.type, context);
          return true;
        }
      }

      return false;
    } catch (e) {
      LoggerFactory.error('Error checking contextual animation: $e');
      return false;
    }
  }

  bool _checkAnimationConditions(
      Map<String, dynamic> conditions, Map<String, dynamic> context) {
    if (conditions.isEmpty) return true;

    for (final entry in conditions.entries) {
      final key = entry.key;
      final expectedValue = entry.value;
      final actualValue = context[key];

      if (actualValue != expectedValue) {
        return false;
      }
    }

    return true;
  }

  // Adaptive UI System
  Future<void> _updateAdaptiveConfiguration(String userId) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableAdaptiveUI) return;

      // Get device info (mock implementation)
      final deviceInfo = await _getDeviceInfo();

      final config = AdaptiveUIConfig(
        deviceType: deviceInfo['type'] ?? 'mobile',
        screenSize: deviceInfo['screenSize'] ?? 'normal',
        isDarkMode: preferences.customSettings['isDarkMode'] ?? false,
        isHighContrast: preferences.customSettings['isHighContrast'] ?? false,
        fontScale: preferences.customSettings['fontScale']?.toDouble() ?? 1.0,
        layoutAdjustments: _calculateLayoutAdjustments(deviceInfo, preferences),
        componentSizes: _calculateComponentSizes(deviceInfo, preferences),
        spacingMultipliers:
            _calculateSpacingMultipliers(deviceInfo, preferences),
      );

      _adaptiveConfigs[userId] = config;
      await _saveAdaptiveConfigs();
      _adaptiveController.add(config);
    } catch (e) {
      LoggerFactory.error('Error updating adaptive configuration: $e');
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    // Mock implementation - in real app, would use device_info_plus or similar
    return {
      'type': 'mobile',
      'screenSize': 'normal',
      'screenWidth': 390.0,
      'screenHeight': 844.0,
      'devicePixelRatio': 2.0,
      'platform': defaultTargetPlatform.toString(),
    };
  }

  Map<String, dynamic> _calculateLayoutAdjustments(
      Map<String, dynamic> deviceInfo, UXPreferences preferences) {
    final screenWidth = deviceInfo['screenWidth']?.toDouble() ?? 390.0;
    final isTablet = screenWidth > 600;

    return {
      'useTabletLayout': isTablet,
      'columnsInGrid': isTablet ? 3 : 2,
      'useBottomNavigation': !isTablet,
      'useSideNavigation': isTablet,
      'maxContentWidth': isTablet ? 1200.0 : double.infinity,
    };
  }

  Map<String, dynamic> _calculateComponentSizes(
      Map<String, dynamic> deviceInfo, UXPreferences preferences) {
    final fontScale =
        preferences.customSettings['fontScale']?.toDouble() ?? 1.0;
    final isHighContrast =
        preferences.customSettings['isHighContrast'] ?? false;

    return {
      'buttonHeight': (48.0 * fontScale * (isHighContrast ? 1.2 : 1.0)),
      'listItemHeight': (56.0 * fontScale * (isHighContrast ? 1.2 : 1.0)),
      'iconSize': (24.0 * fontScale * (isHighContrast ? 1.3 : 1.0)),
      'minTouchTarget': (44.0 * (isHighContrast ? 1.3 : 1.0)),
    };
  }

  Map<String, dynamic> _calculateSpacingMultipliers(
      Map<String, dynamic> deviceInfo, UXPreferences preferences) {
    final fontScale =
        preferences.customSettings['fontScale']?.toDouble() ?? 1.0;
    final isHighContrast =
        preferences.customSettings['isHighContrast'] ?? false;

    return {
      'horizontalPadding': fontScale * (isHighContrast ? 1.2 : 1.0),
      'verticalPadding': fontScale * (isHighContrast ? 1.2 : 1.0),
      'cardMargin': fontScale * (isHighContrast ? 1.3 : 1.0),
      'sectionSpacing': fontScale * (isHighContrast ? 1.4 : 1.0),
    };
  }

  AdaptiveUIConfig? getAdaptiveConfig(String userId) {
    return _adaptiveConfigs[userId];
  }

  // Initialize Default Configurations
  Future<void> _initializeDefaultConfigurations() async {
    // Initialize default micro-interactions
    if (_microInteractions.isEmpty) {
      _microInteractions.addAll({
        MicroInteractionType.buttonPress: const MicroInteractionConfig(
          type: MicroInteractionType.buttonPress,
          duration: Duration(milliseconds: 150),
          curve: 'easeInOut',
          enableHaptic: true,
          hapticType: HapticType.light,
        ),
        MicroInteractionType.cardSelection: const MicroInteractionConfig(
          type: MicroInteractionType.cardSelection,
          duration: Duration(milliseconds: 200),
          curve: 'easeOutBack',
          enableHaptic: true,
          hapticType: HapticType.selection,
        ),
        MicroInteractionType.listScroll: const MicroInteractionConfig(
          type: MicroInteractionType.listScroll,
          duration: Duration(milliseconds: 100),
          curve: 'linear',
          enableHaptic: false,
        ),
        MicroInteractionType.tabSwitch: const MicroInteractionConfig(
          type: MicroInteractionType.tabSwitch,
          duration: Duration(milliseconds: 250),
          curve: 'easeInOutCubic',
          enableHaptic: true,
          hapticType: HapticType.selection,
        ),
        MicroInteractionType.modalOpen: const MicroInteractionConfig(
          type: MicroInteractionType.modalOpen,
          duration: Duration(milliseconds: 300),
          curve: 'easeOutQuart',
          enableHaptic: true,
          hapticType: HapticType.medium,
        ),
        MicroInteractionType.success: const MicroInteractionConfig(
          type: MicroInteractionType.success,
          duration: Duration(milliseconds: 400),
          curve: 'bounceOut',
          enableHaptic: true,
          hapticType: HapticType.success,
        ),
        MicroInteractionType.error: const MicroInteractionConfig(
          type: MicroInteractionType.error,
          duration: Duration(milliseconds: 300),
          curve: 'easeOutBack',
          enableHaptic: true,
          hapticType: HapticType.error,
        ),
      });

      await _saveMicroInteractions();
    }

    // Initialize default contextual animations
    if (_contextualAnimations.isEmpty) {
      await registerContextualAnimation(
        const ContextualAnimation(
          id: 'welcome_first_time',
          name: 'Welcome First Time User',
          trigger: 'app_first_launch',
          conditions: {'isFirstTime': true},
          animation: MicroInteractionConfig(
            type: MicroInteractionType.modalOpen,
            duration: Duration(milliseconds: 500),
            curve: 'bounceOut',
            enableHaptic: true,
            hapticType: HapticType.success,
          ),
          priority: 10,
        ),
      );

      await registerContextualAnimation(
        const ContextualAnimation(
          id: 'achievement_unlock',
          name: 'Achievement Unlocked',
          trigger: 'achievement_earned',
          animation: MicroInteractionConfig(
            type: MicroInteractionType.success,
            duration: Duration(milliseconds: 600),
            curve: 'elasticOut',
            enableHaptic: true,
            hapticType: HapticType.success,
          ),
          priority: 8,
        ),
      );
    }
  }

  // Persistence Methods
  Future<void> _loadUXPreferences() async {
    final json = _prefs?.getString(_uxPreferencesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userPreferences.clear();
      data.forEach((key, value) {
        _userPreferences[key] = UXPreferences.fromJson(value);
      });
    }
  }

  Future<void> _saveUXPreferences() async {
    final data = <String, dynamic>{};
    _userPreferences.forEach((key, preferences) {
      data[key] = preferences.toJson();
    });
    await _prefs?.setString(_uxPreferencesKey, jsonEncode(data));
  }

  Future<void> _loadGestureShortcuts() async {
    final json = _prefs?.getString(_gestureShortcutsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userGestureShortcuts.clear();
      data.forEach((userId, shortcutsList) {
        _userGestureShortcuts[userId] = (shortcutsList as List<dynamic>)
            .map((s) => GestureShortcut.fromJson(s))
            .toList();
      });
    }
  }

  Future<void> _saveGestureShortcuts() async {
    final data = <String, dynamic>{};
    _userGestureShortcuts.forEach((userId, shortcuts) {
      data[userId] = shortcuts.map((s) => s.toJson()).toList();
    });
    await _prefs?.setString(_gestureShortcutsKey, jsonEncode(data));
  }

  Future<void> _loadAnimationProfiles() async {
    final json = _prefs?.getString(_animationProfilesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _animationProfiles.clear();
      data.forEach((key, value) {
        _animationProfiles[key] = AnimationProfile.fromJson(value);
      });
    }
  }

  Future<void> _saveAnimationProfiles() async {
    final data = <String, dynamic>{};
    _animationProfiles.forEach((key, profile) {
      data[key] = profile.toJson();
    });
    await _prefs?.setString(_animationProfilesKey, jsonEncode(data));
  }

  Future<void> _loadMicroInteractions() async {
    final json = _prefs?.getString(_microInteractionsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _microInteractions.clear();
      data.forEach((key, value) {
        final type = MicroInteractionType.values.firstWhere(
          (e) => e.toString() == key,
          orElse: () => MicroInteractionType.buttonPress,
        );
        _microInteractions[type] = MicroInteractionConfig.fromJson(value);
      });
    }
  }

  Future<void> _saveMicroInteractions() async {
    final data = <String, dynamic>{};
    _microInteractions.forEach((type, config) {
      data[type.toString()] = config.toJson();
    });
    await _prefs?.setString(_microInteractionsKey, jsonEncode(data));
  }

  Future<void> _loadContextualAnimations() async {
    final json = _prefs?.getString(_contextualAnimationsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _contextualAnimations.clear();
      data.forEach((key, value) {
        _contextualAnimations[key] = ContextualAnimation.fromJson(value);
      });
    }
  }

  Future<void> _saveContextualAnimations() async {
    final data = <String, dynamic>{};
    _contextualAnimations.forEach((key, animation) {
      data[key] = animation.toJson();
    });
    await _prefs?.setString(_contextualAnimationsKey, jsonEncode(data));
  }

  Future<void> _loadAdaptiveConfigs() async {
    final json = _prefs?.getString(_adaptiveConfigKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _adaptiveConfigs.clear();
      data.forEach((key, value) {
        _adaptiveConfigs[key] = AdaptiveUIConfig.fromJson(value);
      });
    }
  }

  Future<void> _saveAdaptiveConfigs() async {
    final data = <String, dynamic>{};
    _adaptiveConfigs.forEach((key, config) {
      data[key] = config.toJson();
    });
    await _prefs?.setString(_adaptiveConfigKey, jsonEncode(data));
  }

  // Dispose
  void dispose() {
    _preferencesController.close();
    _gesturesController.close();
    _animationController.close();
    _adaptiveController.close();
  }
}
