enum AdSenseOverlayState {
  loaded,
  dismissed,
  timeout,
  failure,
}

class AdSenseOverlayResult {
  const AdSenseOverlayResult({
    required this.state,
    this.reason,
  });

  const AdSenseOverlayResult.loaded() : this(state: AdSenseOverlayState.loaded);

  const AdSenseOverlayResult.dismissed()
      : this(state: AdSenseOverlayState.dismissed);

  const AdSenseOverlayResult.timeout()
      : this(state: AdSenseOverlayState.timeout, reason: 'timeout');

  const AdSenseOverlayResult.failure(String reason)
      : this(state: AdSenseOverlayState.failure, reason: reason);

  final AdSenseOverlayState state;
  final String? reason;

  bool get isLoaded => state == AdSenseOverlayState.loaded;
  bool get isDismissed => state == AdSenseOverlayState.dismissed;
  bool get isTimeout => state == AdSenseOverlayState.timeout;
  bool get isFailure => state == AdSenseOverlayState.failure;
}
