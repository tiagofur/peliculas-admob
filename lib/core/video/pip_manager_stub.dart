/// Stub implementation for PiP Manager
/// Used when no platform-specific implementation is available
library pip_manager_stub;

import '../../core/logging/logger_factory.dart';
import 'pip_manager.dart';

/// Returns a stub PiP manager for unsupported platforms
PipManager getPipManager() => PipManagerStub();

/// Stub implementation for unsupported platforms
class PipManagerStub implements PipManager {
  @override
  bool get isPipSupported => false;

  @override
  bool get isPipActive => false;

  @override
  Future<bool> enterPipMode({
    required String youtubeId,
    required String movieTitle,
  }) async {
    LoggerFactory.warning('PiP not supported on this platform');
    return false;
  }

  @override
  Future<bool> exitPipMode() async {
    LoggerFactory.warning('PiP not supported on this platform');
    return false;
  }

  @override
  Future<void> updatePipParams() async {
    // No-op for unsupported platforms
  }

  @override
  void dispose() {
    // No-op for stub
  }
}

