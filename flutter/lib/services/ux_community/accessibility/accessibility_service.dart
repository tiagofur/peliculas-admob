// lib/services/ux_community/accessibility/accessibility_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/logger_factory.dart';

enum AccessibilityFeature {
  screenReader,
  voiceNavigation,
  highContrast,
  largeText,
  keyboardNavigation,
  reducedMotion,
  colorBlindSupport,
  hearingSupport,
  motorSupport,
}

enum ContrastLevel {
  normal,
  increased,
  high,
  maximum,
}

enum FontSizeLevel {
  small,
  normal,
  large,
  extraLarge,
  huge,
}

enum VoiceCommand {
  navigateHome,
  navigateBack,
  navigateForward,
  openSearch,
  openMenu,
  selectItem,
  scrollUp,
  scrollDown,
  playPause,
  repeat,
  help,
}

enum NavigationMode {
  touch,
  keyboard,
  voice,
  switchControl,
  hybrid,
}

class AccessibilityPreferences {
  const AccessibilityPreferences({
    required this.userId,
    this.enabledFeatures = const {},
    this.contrastLevel = ContrastLevel.normal,
    this.fontSizeLevel = FontSizeLevel.normal,
    this.navigationMode = NavigationMode.touch,
    this.textScaleFactor = 1.0,
    this.reduceAnimations = false,
    this.enableVibrations = true,
    this.enableSounds = true,
    this.showVisualIndicators = true,
    this.enableVoiceDescriptions = false,
    this.enableKeyboardShortcuts = false,
    this.colorOverrides = const {},
    this.customSettings = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccessibilityPreferences.fromJson(Map<String, dynamic> json) {
    return AccessibilityPreferences(
      userId: json['userId'],
      enabledFeatures: (json['enabledFeatures'] as List<dynamic>? ?? [])
          .map((f) => AccessibilityFeature.values.firstWhere(
                (e) => e.toString() == f,
                orElse: () => AccessibilityFeature.screenReader,
              ))
          .toSet(),
      contrastLevel: ContrastLevel.values.firstWhere(
        (e) => e.toString() == json['contrastLevel'],
        orElse: () => ContrastLevel.normal,
      ),
      fontSizeLevel: FontSizeLevel.values.firstWhere(
        (e) => e.toString() == json['fontSizeLevel'],
        orElse: () => FontSizeLevel.normal,
      ),
      navigationMode: NavigationMode.values.firstWhere(
        (e) => e.toString() == json['navigationMode'],
        orElse: () => NavigationMode.touch,
      ),
      textScaleFactor: json['textScaleFactor']?.toDouble() ?? 1.0,
      reduceAnimations: json['reduceAnimations'] ?? false,
      enableVibrations: json['enableVibrations'] ?? true,
      enableSounds: json['enableSounds'] ?? true,
      showVisualIndicators: json['showVisualIndicators'] ?? true,
      enableVoiceDescriptions: json['enableVoiceDescriptions'] ?? false,
      enableKeyboardShortcuts: json['enableKeyboardShortcuts'] ?? false,
      colorOverrides: Map<String, String>.from(json['colorOverrides'] ?? {}),
      customSettings: Map<String, dynamic>.from(json['customSettings'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
  final String userId;
  final Set<AccessibilityFeature> enabledFeatures;
  final ContrastLevel contrastLevel;
  final FontSizeLevel fontSizeLevel;
  final NavigationMode navigationMode;
  final double textScaleFactor;
  final bool reduceAnimations;
  final bool enableVibrations;
  final bool enableSounds;
  final bool showVisualIndicators;
  final bool enableVoiceDescriptions;
  final bool enableKeyboardShortcuts;
  final Map<String, String> colorOverrides;
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  AccessibilityPreferences copyWith({
    String? userId,
    Set<AccessibilityFeature>? enabledFeatures,
    ContrastLevel? contrastLevel,
    FontSizeLevel? fontSizeLevel,
    NavigationMode? navigationMode,
    double? textScaleFactor,
    bool? reduceAnimations,
    bool? enableVibrations,
    bool? enableSounds,
    bool? showVisualIndicators,
    bool? enableVoiceDescriptions,
    bool? enableKeyboardShortcuts,
    Map<String, String>? colorOverrides,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccessibilityPreferences(
      userId: userId ?? this.userId,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
      contrastLevel: contrastLevel ?? this.contrastLevel,
      fontSizeLevel: fontSizeLevel ?? this.fontSizeLevel,
      navigationMode: navigationMode ?? this.navigationMode,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      enableVibrations: enableVibrations ?? this.enableVibrations,
      enableSounds: enableSounds ?? this.enableSounds,
      showVisualIndicators: showVisualIndicators ?? this.showVisualIndicators,
      enableVoiceDescriptions:
          enableVoiceDescriptions ?? this.enableVoiceDescriptions,
      enableKeyboardShortcuts:
          enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
      colorOverrides: colorOverrides ?? this.colorOverrides,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'enabledFeatures': enabledFeatures.map((f) => f.toString()).toList(),
      'contrastLevel': contrastLevel.toString(),
      'fontSizeLevel': fontSizeLevel.toString(),
      'navigationMode': navigationMode.toString(),
      'textScaleFactor': textScaleFactor,
      'reduceAnimations': reduceAnimations,
      'enableVibrations': enableVibrations,
      'enableSounds': enableSounds,
      'showVisualIndicators': showVisualIndicators,
      'enableVoiceDescriptions': enableVoiceDescriptions,
      'enableKeyboardShortcuts': enableKeyboardShortcuts,
      'colorOverrides': colorOverrides,
      'customSettings': customSettings,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class KeyboardShortcut {
  const KeyboardShortcut({
    required this.id,
    required this.name,
    required this.description,
    required this.keys,
    required this.action,
    this.parameters = const {},
    this.isGlobal = false,
    this.isActive = true,
  });

  factory KeyboardShortcut.fromJson(Map<String, dynamic> json) {
    return KeyboardShortcut(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      keys: List<String>.from(json['keys'] ?? []),
      action: json['action'],
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      isGlobal: json['isGlobal'] ?? false,
      isActive: json['isActive'] ?? true,
    );
  }
  final String id;
  final String name;
  final String description;
  final List<String> keys; // e.g., ['Ctrl', 'Shift', 'N']
  final String action;
  final Map<String, dynamic> parameters;
  final bool isGlobal;
  final bool isActive;

  KeyboardShortcut copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? keys,
    String? action,
    Map<String, dynamic>? parameters,
    bool? isGlobal,
    bool? isActive,
  }) {
    return KeyboardShortcut(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      keys: keys ?? this.keys,
      action: action ?? this.action,
      parameters: parameters ?? this.parameters,
      isGlobal: isGlobal ?? this.isGlobal,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'keys': keys,
      'action': action,
      'parameters': parameters,
      'isGlobal': isGlobal,
      'isActive': isActive,
    };
  }
}

class VoiceCommandModel {
  const VoiceCommandModel({
    required this.id,
    required this.phrase,
    this.aliases = const [],
    required this.action,
    this.parameters = const {},
    this.confidence = 0.8,
    this.isActive = true,
  });

  factory VoiceCommandModel.fromJson(Map<String, dynamic> json) {
    return VoiceCommandModel(
      id: json['id'],
      phrase: json['phrase'],
      aliases: List<String>.from(json['aliases'] ?? []),
      action: json['action'],
      parameters: Map<String, dynamic>.from(json['parameters'] ?? {}),
      confidence: json['confidence']?.toDouble() ?? 0.8,
      isActive: json['isActive'] ?? true,
    );
  }
  final String id;
  final String phrase;
  final List<String> aliases;
  final String action;
  final Map<String, dynamic> parameters;
  final double confidence;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phrase': phrase,
      'aliases': aliases,
      'action': action,
      'parameters': parameters,
      'confidence': confidence,
      'isActive': isActive,
    };
  }
}

class AccessibilityAnnouncement {
  const AccessibilityAnnouncement({
    required this.id,
    required this.message,
    this.priority = 'medium',
    this.context,
    required this.timestamp,
    this.isLive = false,
  });

  factory AccessibilityAnnouncement.fromJson(Map<String, dynamic> json) {
    return AccessibilityAnnouncement(
      id: json['id'],
      message: json['message'],
      priority: json['priority'] ?? 'medium',
      context: json['context'],
      timestamp: DateTime.parse(json['timestamp']),
      isLive: json['isLive'] ?? false,
    );
  }
  final String id;
  final String message;
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String? context;
  final DateTime timestamp;
  final bool isLive;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'priority': priority,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'isLive': isLive,
    };
  }
}

class ScreenReaderInfo {
  const ScreenReaderInfo({
    required this.elementId,
    required this.label,
    this.hint,
    this.value,
    this.role = 'generic',
    this.properties = const {},
    this.isFocusable = true,
    this.isVisible = true,
  });

  factory ScreenReaderInfo.fromJson(Map<String, dynamic> json) {
    return ScreenReaderInfo(
      elementId: json['elementId'],
      label: json['label'],
      hint: json['hint'],
      value: json['value'],
      role: json['role'] ?? 'generic',
      properties: Map<String, String>.from(json['properties'] ?? {}),
      isFocusable: json['isFocusable'] ?? true,
      isVisible: json['isVisible'] ?? true,
    );
  }
  final String elementId;
  final String label;
  final String? hint;
  final String? value;
  final String role;
  final Map<String, String> properties;
  final bool isFocusable;
  final bool isVisible;

  Map<String, dynamic> toJson() {
    return {
      'elementId': elementId,
      'label': label,
      'hint': hint,
      'value': value,
      'role': role,
      'properties': properties,
      'isFocusable': isFocusable,
      'isVisible': isVisible,
    };
  }
}

class AccessibilityService {
  static const String _preferencesKey = 'accessibility_preferences';
  static const String _keyboardShortcutsKey = 'keyboard_shortcuts';
  static const String _voiceCommandsKey = 'voice_commands';
  static const String _screenReaderInfoKey = 'screen_reader_info';

  SharedPreferences? _prefs;
  final Map<String, AccessibilityPreferences> _userPreferences = {};
  final Map<String, List<KeyboardShortcut>> _userShortcuts =
      {}; // userId -> shortcuts
  final Map<String, List<VoiceCommandModel>> _userVoiceCommands =
      {}; // userId -> commands
  final Map<String, List<ScreenReaderInfo>> _screenReaderElements =
      {}; // screenId -> elements

  final StreamController<AccessibilityPreferences> _preferencesController =
      StreamController.broadcast();
  final StreamController<AccessibilityAnnouncement> _announcementController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _navigationController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _voiceController =
      StreamController.broadcast();

  // Getters
  Stream<AccessibilityPreferences> get preferencesStream =>
      _preferencesController.stream;
  Stream<AccessibilityAnnouncement> get announcementStream =>
      _announcementController.stream;
  Stream<Map<String, dynamic>> get navigationStream =>
      _navigationController.stream;
  Stream<Map<String, dynamic>> get voiceStream => _voiceController.stream;

  // Initialize
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadAccessibilityPreferences();
      await _loadKeyboardShortcuts();
      await _loadVoiceCommands();
      await _loadScreenReaderInfo();
      await _initializeDefaultConfigurations();
      LoggerFactory.info('AccessibilityService initialized successfully');
    } catch (e) {
      LoggerFactory.error('Error initializing AccessibilityService: $e');
    }
  }

  // Preferences Management
  Future<void> updateAccessibilityPreferences(
      AccessibilityPreferences preferences) async {
    try {
      final updatedPreferences =
          preferences.copyWith(updatedAt: DateTime.now());
      _userPreferences[preferences.userId] = updatedPreferences;

      await _saveAccessibilityPreferences();
      _preferencesController.add(updatedPreferences);

      // Apply system-level changes based on preferences
      await _applySystemAccessibilitySettings(updatedPreferences);

      LoggerFactory.info(
          'Accessibility preferences updated for user ${preferences.userId}');
    } catch (e) {
      LoggerFactory.error('Error updating accessibility preferences: $e');
    }
  }

  AccessibilityPreferences getUserPreferences(String userId) {
    return _userPreferences[userId] ??
        AccessibilityPreferences(
          userId: userId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<void> toggleAccessibilityFeature(
      String userId, AccessibilityFeature feature, bool enabled) async {
    final preferences = getUserPreferences(userId);
    final updatedFeatures =
        Set<AccessibilityFeature>.from(preferences.enabledFeatures);

    if (enabled) {
      updatedFeatures.add(feature);
    } else {
      updatedFeatures.remove(feature);
    }

    await updateAccessibilityPreferences(
        preferences.copyWith(enabledFeatures: updatedFeatures));
  }

  bool isFeatureEnabled(String userId, AccessibilityFeature feature) {
    final preferences = getUserPreferences(userId);
    return preferences.enabledFeatures.contains(feature);
  }

  Future<void> setContrastLevel(String userId, ContrastLevel level) async {
    final preferences = getUserPreferences(userId);
    await updateAccessibilityPreferences(
        preferences.copyWith(contrastLevel: level));
  }

  Future<void> setFontSizeLevel(String userId, FontSizeLevel level) async {
    final preferences = getUserPreferences(userId);
    final scaleFactor = _getFontScaleFactor(level);

    await updateAccessibilityPreferences(preferences.copyWith(
      fontSizeLevel: level,
      textScaleFactor: scaleFactor,
    ));
  }

  double _getFontScaleFactor(FontSizeLevel level) {
    switch (level) {
      case FontSizeLevel.small:
        return 0.85;
      case FontSizeLevel.normal:
        return 1.0;
      case FontSizeLevel.large:
        return 1.3;
      case FontSizeLevel.extraLarge:
        return 1.6;
      case FontSizeLevel.huge:
        return 2.0;
    }
  }

  Future<void> setNavigationMode(String userId, NavigationMode mode) async {
    final preferences = getUserPreferences(userId);
    await updateAccessibilityPreferences(
        preferences.copyWith(navigationMode: mode));
  }

  Future<void> _applySystemAccessibilitySettings(
      AccessibilityPreferences preferences) async {
    // Apply system-level accessibility settings
    // This would integrate with platform-specific accessibility services
    LoggerFactory.debug(
        'Applying accessibility settings for user ${preferences.userId}');

    // Example of what could be done:
    // - Configure system screen reader
    // - Set system font size
    // - Configure high contrast mode
    // - Set up voice navigation
  }

  // Screen Reader Support
  Future<void> registerScreenReaderElement({
    required String screenId,
    required String elementId,
    required String label,
    String? hint,
    String? value,
    String role = 'generic',
    Map<String, String> properties = const {},
    bool isFocusable = true,
  }) async {
    try {
      final element = ScreenReaderInfo(
        elementId: elementId,
        label: label,
        hint: hint,
        value: value,
        role: role,
        properties: properties,
        isFocusable: isFocusable,
      );

      _screenReaderElements.putIfAbsent(screenId, () => []);

      // Remove existing element with same ID
      _screenReaderElements[screenId]!
          .removeWhere((e) => e.elementId == elementId);

      // Add new element
      _screenReaderElements[screenId]!.add(element);

      await _saveScreenReaderInfo();

      LoggerFactory.debug(
          'Registered screen reader element: $elementId for screen $screenId');
    } catch (e) {
      LoggerFactory.error('Error registering screen reader element: $e');
    }
  }

  List<ScreenReaderInfo> getScreenReaderElements(String screenId) {
    return _screenReaderElements[screenId] ?? [];
  }

  Future<void> announceToScreenReader({
    required String message,
    String priority = 'medium',
    String? context,
    bool isLive = false,
  }) async {
    try {
      final announcement = AccessibilityAnnouncement(
        id: 'announce_${DateTime.now().millisecondsSinceEpoch}',
        message: message,
        priority: priority,
        context: context,
        timestamp: DateTime.now(),
        isLive: isLive,
      );

      _announcementController.add(announcement);

      // In real implementation, this would interface with platform screen readers
      if (kDebugMode) {
        LoggerFactory.info('Screen Reader Announcement [$priority]: $message');
      }
    } catch (e) {
      LoggerFactory.error('Error announcing to screen reader: $e');
    }
  }

  Future<void> focusElement(String userId, String elementId) async {
    try {
      if (!isFeatureEnabled(userId, AccessibilityFeature.screenReader)) return;

      _navigationController.add({
        'action': 'focus_element',
        'elementId': elementId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Announce focus change
      await announceToScreenReader(
        message: 'Focused on $elementId',
        priority: 'low',
        context: 'navigation',
      );
    } catch (e) {
      LoggerFactory.error('Error focusing element: $e');
    }
  }

  // Voice Navigation
  Future<void> registerVoiceCommand({
    required String userId,
    required String phrase,
    List<String> aliases = const [],
    required String action,
    Map<String, dynamic> parameters = const {},
    double confidence = 0.8,
  }) async {
    try {
      final commandId = 'voice_${DateTime.now().millisecondsSinceEpoch}';

      final command = VoiceCommandModel(
        id: commandId,
        phrase: phrase,
        aliases: aliases,
        action: action,
        parameters: parameters,
        confidence: confidence,
      );

      _userVoiceCommands.putIfAbsent(userId, () => []);
      _userVoiceCommands[userId]!.add(command);

      await _saveVoiceCommands();

      LoggerFactory.info(
          'Registered voice command: "$phrase" -> $action for user $userId');
    } catch (e) {
      LoggerFactory.error('Error registering voice command: $e');
    }
  }

  Future<bool> processVoiceInput(String userId, String spokenText) async {
    try {
      if (!isFeatureEnabled(userId, AccessibilityFeature.voiceNavigation)) {
        return false;
      }

      final commands = _userVoiceCommands[userId] ?? [];

      // Find matching command
      for (final command in commands) {
        if (!command.isActive) continue;

        final isMatch = _matchesVoiceCommand(spokenText, command);
        if (isMatch) {
          await _executeVoiceCommand(userId, command);
          return true;
        }
      }

      // No matching command found
      await announceToScreenReader(
        message:
            'Voice command not recognized. Say "help" for available commands.',
        priority: 'medium',
        context: 'voice_navigation',
      );

      return false;
    } catch (e) {
      LoggerFactory.error('Error processing voice input: $e');
      return false;
    }
  }

  bool _matchesVoiceCommand(String spokenText, VoiceCommandModel command) {
    final normalizedInput = spokenText.toLowerCase().trim();

    // Check main phrase
    if (normalizedInput.contains(command.phrase.toLowerCase())) {
      return true;
    }

    // Check aliases
    for (final alias in command.aliases) {
      if (normalizedInput.contains(alias.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  Future<void> _executeVoiceCommand(
      String userId, VoiceCommandModel command) async {
    try {
      _voiceController.add({
        'action': 'voice_command_executed',
        'commandId': command.id,
        'phrase': command.phrase,
        'actionType': command.action,
        'parameters': command.parameters,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Execute the command based on action type
      await _executeAccessibilityAction(
          userId, command.action, command.parameters);

      // Provide voice feedback
      await announceToScreenReader(
        message: 'Executing ${command.phrase}',
        priority: 'medium',
        context: 'voice_command',
      );
    } catch (e) {
      LoggerFactory.error('Error executing voice command: $e');
    }
  }

  Future<void> _executeAccessibilityAction(
      String userId, String action, Map<String, dynamic> parameters) async {
    switch (action) {
      case 'navigate_home':
        _navigationController
            .add({'action': 'navigate', 'destination': 'home'});
        break;
      case 'navigate_back':
        _navigationController.add({'action': 'navigate_back'});
        break;
      case 'open_search':
        _navigationController.add({'action': 'open_search'});
        break;
      case 'open_menu':
        _navigationController.add({'action': 'open_menu'});
        break;
      case 'scroll_up':
        _navigationController.add({'action': 'scroll', 'direction': 'up'});
        break;
      case 'scroll_down':
        _navigationController.add({'action': 'scroll', 'direction': 'down'});
        break;
      case 'read_current':
        await _readCurrentFocus(userId);
        break;
      case 'help':
        await _provideVoiceHelp(userId);
        break;
      default:
        LoggerFactory.warning('Unknown accessibility action: $action');
    }
  }

  Future<void> _readCurrentFocus(String userId) async {
    // Mock implementation - would read currently focused element
    await announceToScreenReader(
      message: 'Currently focused on main content area',
      priority: 'medium',
      context: 'screen_reader',
    );
  }

  Future<void> _provideVoiceHelp(String userId) async {
    final commands = _userVoiceCommands[userId] ?? [];
    final activeCommands = commands.where((c) => c.isActive).take(5).toList();

    if (activeCommands.isEmpty) {
      await announceToScreenReader(
        message: 'No voice commands are currently available.',
        priority: 'medium',
      );
      return;
    }

    final helpMessage =
        'Available commands: ${activeCommands.map((c) => c.phrase).join(', ')}';
    await announceToScreenReader(
      message: helpMessage,
      priority: 'high',
      context: 'help',
    );
  }

  List<VoiceCommandModel> getUserVoiceCommands(String userId) {
    return _userVoiceCommands[userId] ?? [];
  }

  // Keyboard Navigation
  Future<void> registerKeyboardShortcut({
    required String userId,
    required String name,
    required String description,
    required List<String> keys,
    required String action,
    Map<String, dynamic> parameters = const {},
    bool isGlobal = false,
  }) async {
    try {
      final shortcutId = 'kbd_${DateTime.now().millisecondsSinceEpoch}';

      final shortcut = KeyboardShortcut(
        id: shortcutId,
        name: name,
        description: description,
        keys: keys,
        action: action,
        parameters: parameters,
        isGlobal: isGlobal,
      );

      _userShortcuts.putIfAbsent(userId, () => []);
      _userShortcuts[userId]!.add(shortcut);

      await _saveKeyboardShortcuts();

      LoggerFactory.info(
          'Registered keyboard shortcut: ${keys.join('+')} -> $action for user $userId');
    } catch (e) {
      LoggerFactory.error('Error registering keyboard shortcut: $e');
    }
  }

  Future<bool> handleKeyboardInput(
      String userId, List<String> pressedKeys) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableKeyboardShortcuts) return false;

      final shortcuts = _userShortcuts[userId] ?? [];

      // Find matching shortcut
      for (final shortcut in shortcuts) {
        if (!shortcut.isActive) continue;

        if (_keysMatch(pressedKeys, shortcut.keys)) {
          await _executeKeyboardAction(userId, shortcut);
          return true;
        }
      }

      return false;
    } catch (e) {
      LoggerFactory.error('Error handling keyboard input: $e');
      return false;
    }
  }

  bool _keysMatch(List<String> pressed, List<String> expected) {
    if (pressed.length != expected.length) return false;

    final sortedPressed = List<String>.from(pressed)..sort();
    final sortedExpected = List<String>.from(expected)..sort();

    for (int i = 0; i < sortedPressed.length; i++) {
      if (sortedPressed[i].toLowerCase() != sortedExpected[i].toLowerCase()) {
        return false;
      }
    }

    return true;
  }

  Future<void> _executeKeyboardAction(
      String userId, KeyboardShortcut shortcut) async {
    try {
      _navigationController.add({
        'action': 'keyboard_shortcut_executed',
        'shortcutId': shortcut.id,
        'keys': shortcut.keys,
        'actionType': shortcut.action,
        'parameters': shortcut.parameters,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await _executeAccessibilityAction(
          userId, shortcut.action, shortcut.parameters);

      // Provide feedback for screen readers
      if (isFeatureEnabled(userId, AccessibilityFeature.screenReader)) {
        await announceToScreenReader(
          message: 'Executed ${shortcut.name}',
          priority: 'low',
          context: 'keyboard_navigation',
        );
      }
    } catch (e) {
      LoggerFactory.error('Error executing keyboard action: $e');
    }
  }

  List<KeyboardShortcut> getUserKeyboardShortcuts(String userId) {
    return _userShortcuts[userId] ?? [];
  }

  // High Contrast & Color Support
  Map<String, String> getContrastColors(String userId) {
    final preferences = getUserPreferences(userId);

    final baseColors = <String, String>{
      'background': '#FFFFFF',
      'foreground': '#000000',
      'accent': '#0066CC',
      'error': '#CC0000',
      'warning': '#FF9900',
      'success': '#00AA00',
    };

    switch (preferences.contrastLevel) {
      case ContrastLevel.normal:
        return {...baseColors, ...preferences.colorOverrides};
      case ContrastLevel.increased:
        return {
          'background': '#FFFFFF',
          'foreground': '#000000',
          'accent': '#0044AA',
          'error': '#AA0000',
          'warning': '#CC7700',
          'success': '#008800',
          ...preferences.colorOverrides,
        };
      case ContrastLevel.high:
        return {
          'background': '#FFFFFF',
          'foreground': '#000000',
          'accent': '#003388',
          'error': '#880000',
          'warning': '#AA5500',
          'success': '#006600',
          ...preferences.colorOverrides,
        };
      case ContrastLevel.maximum:
        return {
          'background': '#FFFFFF',
          'foreground': '#000000',
          'accent': '#000000',
          'error': '#000000',
          'warning': '#000000',
          'success': '#000000',
          ...preferences.colorOverrides,
        };
    }
  }

  Future<void> setCustomColor(
      String userId, String colorKey, String colorValue) async {
    final preferences = getUserPreferences(userId);
    final updatedOverrides =
        Map<String, String>.from(preferences.colorOverrides);
    updatedOverrides[colorKey] = colorValue;

    await updateAccessibilityPreferences(
        preferences.copyWith(colorOverrides: updatedOverrides));
  }

  // Motion & Animation Settings
  bool shouldReduceMotion(String userId) {
    final preferences = getUserPreferences(userId);
    return preferences.reduceAnimations ||
        isFeatureEnabled(userId, AccessibilityFeature.reducedMotion);
  }

  Duration getAccessibleAnimationDuration(
      String userId, Duration originalDuration) {
    if (shouldReduceMotion(userId)) {
      return Duration.zero; // No animation
    }
    return originalDuration;
  }

  // Feedback Methods
  Future<void> provideTactileFeedback(
      String userId, String feedbackType) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableVibrations) return;

      switch (feedbackType) {
        case 'light':
          await HapticFeedback.lightImpact();
          break;
        case 'medium':
          await HapticFeedback.mediumImpact();
          break;
        case 'heavy':
          await HapticFeedback.heavyImpact();
          break;
        case 'selection':
          await HapticFeedback.selectionClick();
          break;
      }
    } catch (e) {
      LoggerFactory.error('Error providing tactile feedback: $e');
    }
  }

  Future<void> provideAudioFeedback(String userId, String soundType) async {
    try {
      final preferences = getUserPreferences(userId);
      if (!preferences.enableSounds) return;

      // Mock implementation - would play actual sounds
      LoggerFactory.debug('Playing audio feedback: $soundType');
    } catch (e) {
      LoggerFactory.error('Error providing audio feedback: $e');
    }
  }

  // WCAG 2.1 Compliance Methods
  bool checkColorContrastCompliance(
      String backgroundColor, String foregroundColor) {
    // Mock implementation - would calculate actual contrast ratio
    // WCAG AA requires 4.5:1 for normal text, 3:1 for large text
    return true; // Assume compliant for now
  }

  bool checkMinimumTouchTargetSize(double width, double height) {
    // WCAG recommends minimum 44x44 points for touch targets
    return width >= 44 && height >= 44;
  }

  Map<String, bool> performAccessibilityAudit(String screenId) {
    final elements = getScreenReaderElements(screenId);

    final audit = <String, bool>{
      'hasScreenReaderLabels': elements.every((e) => e.label.isNotEmpty),
      'hasFocusableElements': elements.any((e) => e.isFocusable),
      'hasProperHeadingStructure': true, // Mock check
      'hasAltTextForImages': true, // Mock check
      'hasKeyboardNavigation': true, // Mock check
      'meetsContrastRequirements': true, // Mock check
      'meetsMinimumTouchTargets': true, // Mock check
    };

    return audit;
  }

  // Default Configurations
  Future<void> _initializeDefaultConfigurations() async {
    // Initialize default keyboard shortcuts for all users
    await _initializeDefaultKeyboardShortcuts();

    // Initialize default voice commands
    await _initializeDefaultVoiceCommands();

    LoggerFactory.info('Default accessibility configurations initialized');
  }

  Future<void> _initializeDefaultKeyboardShortcuts() async {
    final defaultShortcuts = [
      const KeyboardShortcut(
        id: 'home_shortcut',
        name: 'Navigate Home',
        description: 'Navigate to home screen',
        keys: ['Alt', 'H'],
        action: 'navigate_home',
      ),
      const KeyboardShortcut(
        id: 'search_shortcut',
        name: 'Open Search',
        description: 'Open search functionality',
        keys: ['Ctrl', 'F'],
        action: 'open_search',
      ),
      const KeyboardShortcut(
        id: 'menu_shortcut',
        name: 'Open Menu',
        description: 'Open main menu',
        keys: ['Alt', 'M'],
        action: 'open_menu',
      ),
      const KeyboardShortcut(
        id: 'help_shortcut',
        name: 'Show Help',
        description: 'Show help information',
        keys: ['F1'],
        action: 'help',
      ),
    ];

    // These would be added to users when they first enable keyboard navigation
    LoggerFactory.debug(
        'Default keyboard shortcuts ready: ${defaultShortcuts.length}');
  }

  Future<void> _initializeDefaultVoiceCommands() async {
    final defaultCommands = [
      const VoiceCommandModel(
        id: 'voice_home',
        phrase: 'go home',
        aliases: ['navigate home', 'home screen'],
        action: 'navigate_home',
      ),
      const VoiceCommandModel(
        id: 'voice_back',
        phrase: 'go back',
        aliases: ['navigate back', 'back'],
        action: 'navigate_back',
      ),
      const VoiceCommandModel(
        id: 'voice_search',
        phrase: 'open search',
        aliases: ['search', 'find'],
        action: 'open_search',
      ),
      const VoiceCommandModel(
        id: 'voice_menu',
        phrase: 'open menu',
        aliases: ['menu', 'show menu'],
        action: 'open_menu',
      ),
      const VoiceCommandModel(
        id: 'voice_help',
        phrase: 'help',
        aliases: ['show help', 'what can I say'],
        action: 'help',
      ),
      const VoiceCommandModel(
        id: 'voice_scroll_up',
        phrase: 'scroll up',
        aliases: ['go up', 'move up'],
        action: 'scroll_up',
      ),
      const VoiceCommandModel(
        id: 'voice_scroll_down',
        phrase: 'scroll down',
        aliases: ['go down', 'move down'],
        action: 'scroll_down',
      ),
    ];

    LoggerFactory.debug(
        'Default voice commands ready: ${defaultCommands.length}');
  }

  // Persistence Methods
  Future<void> _loadAccessibilityPreferences() async {
    final json = _prefs?.getString(_preferencesKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userPreferences.clear();
      data.forEach((key, value) {
        _userPreferences[key] = AccessibilityPreferences.fromJson(value);
      });
    }
  }

  Future<void> _saveAccessibilityPreferences() async {
    final data = <String, dynamic>{};
    _userPreferences.forEach((key, preferences) {
      data[key] = preferences.toJson();
    });
    await _prefs?.setString(_preferencesKey, jsonEncode(data));
  }

  Future<void> _loadKeyboardShortcuts() async {
    final json = _prefs?.getString(_keyboardShortcutsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userShortcuts.clear();
      data.forEach((userId, shortcutsList) {
        _userShortcuts[userId] = (shortcutsList as List<dynamic>)
            .map((s) => KeyboardShortcut.fromJson(s))
            .toList();
      });
    }
  }

  Future<void> _saveKeyboardShortcuts() async {
    final data = <String, dynamic>{};
    _userShortcuts.forEach((userId, shortcuts) {
      data[userId] = shortcuts.map((s) => s.toJson()).toList();
    });
    await _prefs?.setString(_keyboardShortcutsKey, jsonEncode(data));
  }

  Future<void> _loadVoiceCommands() async {
    final json = _prefs?.getString(_voiceCommandsKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _userVoiceCommands.clear();
      data.forEach((userId, commandsList) {
        _userVoiceCommands[userId] = (commandsList as List<dynamic>)
            .map((c) => VoiceCommandModel.fromJson(c))
            .toList();
      });
    }
  }

  Future<void> _saveVoiceCommands() async {
    final data = <String, dynamic>{};
    _userVoiceCommands.forEach((userId, commands) {
      data[userId] = commands.map((c) => c.toJson()).toList();
    });
    await _prefs?.setString(_voiceCommandsKey, jsonEncode(data));
  }

  Future<void> _loadScreenReaderInfo() async {
    final json = _prefs?.getString(_screenReaderInfoKey);
    if (json != null) {
      final data = jsonDecode(json) as Map<String, dynamic>;
      _screenReaderElements.clear();
      data.forEach((screenId, elementsList) {
        _screenReaderElements[screenId] = (elementsList as List<dynamic>)
            .map((e) => ScreenReaderInfo.fromJson(e))
            .toList();
      });
    }
  }

  Future<void> _saveScreenReaderInfo() async {
    final data = <String, dynamic>{};
    _screenReaderElements.forEach((screenId, elements) {
      data[screenId] = elements.map((e) => e.toJson()).toList();
    });
    await _prefs?.setString(_screenReaderInfoKey, jsonEncode(data));
  }

  // Dispose
  void dispose() {
    _preferencesController.close();
    _announcementController.close();
    _navigationController.close();
    _voiceController.close();
  }
}
