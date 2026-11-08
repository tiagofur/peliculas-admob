import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'adsense_dom_models.dart';

class AdSenseDomAdapter {
  const AdSenseDomAdapter();

  bool get isLocalhost => web.window.location.hostname == 'localhost';

  bool elementExistsById(String elementId) =>
      web.document.getElementById(elementId) != null;

  Future<void> injectScript({
    required String scriptId,
    required String scriptSrc,
    String? crossOrigin,
  }) async {
    final existingElement = web.document.getElementById(scriptId);
    if (existingElement != null) {
      return;
    }

    final head = web.document.head;
    if (head == null) {
      throw StateError('Unable to locate <head> element for script injection.');
    }

    final script = web.HTMLScriptElement()
      ..id = scriptId
      ..async = true
      ..src = scriptSrc;

    if (crossOrigin != null) {
      script.crossOrigin = crossOrigin;
    }

    final completer = Completer<void>();

    late final JSFunction onLoad;
    late final JSFunction onError;

    onLoad = ((web.Event _) {
      script.removeEventListener('load', onLoad);
      script.removeEventListener('error', onError);
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).toJS;

    onError = ((web.Event event) {
      script.removeEventListener('load', onLoad);
      script.removeEventListener('error', onError);
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Failed to load script "$scriptSrc" (${event.type}).'),
        );
      }
    }).toJS;

    script.addEventListener('load', onLoad);
    script.addEventListener('error', onError);

    head.append(script);

    await completer.future;
  }

  Future<AdSenseOverlayResult> mountInterstitialOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 8),
    void Function()? onLoaded,
    void Function()? onClose,
  }) {
    return _mountOverlay(
      overlayId: overlayId,
      overlayCssClass: 'adsense-interstitial',
      adElementId: adElementId,
      adHtml: adHtml,
      closeButtonLabel: closeButtonLabel,
      timeout: timeout,
      onLoaded: onLoaded,
      onClose: onClose,
    );
  }

  Future<AdSenseOverlayResult> mountRewardedOverlay({
    required String overlayId,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    Duration timeout = const Duration(seconds: 12),
    void Function()? onLoaded,
    void Function()? onClose,
  }) {
    return _mountOverlay(
      overlayId: overlayId,
      overlayCssClass: 'adsense-rewarded',
      adElementId: adElementId,
      adHtml: adHtml,
      closeButtonLabel: closeButtonLabel,
      timeout: timeout,
      onLoaded: onLoaded,
      onClose: onClose,
    );
  }

  Future<AdSenseOverlayResult> _mountOverlay({
    required String overlayId,
    required String overlayCssClass,
    required String adElementId,
    required String adHtml,
    required String closeButtonLabel,
    required Duration timeout,
    void Function()? onLoaded,
    void Function()? onClose,
  }) async {
    final body = web.document.body;
    if (body == null) {
      return const AdSenseOverlayResult.failure('body_not_found');
    }

    removeElementById(overlayId);

    final overlay = web.HTMLDivElement()
      ..id = overlayId
      ..className = '$overlayCssClass-overlay';

    overlay.style
      ..position = 'fixed'
      ..zIndex = '2147483647'
      ..left = '0'
      ..top = '0'
      ..width = '100vw'
      ..height = '100vh'
      ..display = 'flex'
      ..alignItems = 'center'
      ..justifyContent = 'center'
      ..backgroundColor = 'rgba(0, 0, 0, 0.75)'
      ..padding = '16px';

    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');

    final content = web.HTMLDivElement()
      ..className = '$overlayCssClass-content';
    content.style
      ..backgroundColor = '#000000'
      ..borderRadius = '12px'
      ..boxShadow = '0 12px 32px rgba(0,0,0,0.45)'
      ..maxWidth = '480px'
      ..width = '100%'
      ..maxHeight = '90vh'
      ..display = 'flex'
      ..flexDirection = 'column'
      ..overflow = 'hidden';

    final closeButton = web.HTMLButtonElement()
      ..id = '${overlayId}_close'
      ..type = 'button'
      ..textContent = closeButtonLabel
      ..className = '$overlayCssClass-close';
    closeButton.style
      ..alignSelf = 'flex-end'
      ..backgroundColor = 'transparent'
      ..border = 'none'
      ..color = '#ffffff'
      ..cursor = 'pointer'
      ..fontSize = '16px'
      ..padding = '12px 16px'
      ..textDecoration = 'underline';
    closeButton.setAttribute('aria-label', closeButtonLabel);

    final adHost = web.HTMLDivElement()
      ..id = '${adElementId}_host'
      ..innerHTML = adHtml.toJS;
    adHost.style
      ..flex = '1'
      ..display = 'flex'
      ..alignItems = 'center'
      ..justifyContent = 'center'
      ..backgroundColor = '#ffffff';

    content.append(closeButton);
    content.append(adHost);
    overlay.append(content);
    body.append(overlay);

    final adElement = web.document.getElementById(adElementId);
    if (adElement == null) {
      removeElementById(overlayId);
      return const AdSenseOverlayResult.failure('ad_element_missing');
    }

    final completer = Completer<AdSenseOverlayResult>();
    var completed = false;

    void complete(AdSenseOverlayResult result) {
      if (completed) return;
      completed = true;
      completer.complete(result);
    }

    var adLoaded = false;
    Timer? timeoutTimer;

    late final JSFunction observerCallback;
    observerCallback =
        ((JSArray<web.MutationRecord> _, web.MutationObserver observerRef) {
      final iframe = adElement.querySelector('iframe');
      if (iframe != null && !adLoaded) {
        adLoaded = true;
        observerRef.disconnect();
        timeoutTimer?.cancel();
        onLoaded?.call();
      }
    }).toJS;

    final observer = web.MutationObserver(observerCallback);

    observer.observe(
      adElement,
      web.MutationObserverInit(childList: true, subtree: true),
    );

    timeoutTimer = Timer(timeout, () {
      observer.disconnect();
      removeElementById(overlayId);
      complete(const AdSenseOverlayResult.timeout());
    });

    late final JSFunction closeListener;
    closeListener = ((web.Event event) {
      event.preventDefault();
      observer.disconnect();
      timeoutTimer?.cancel();
      removeElementById(overlayId);
      onClose?.call();
      if (adLoaded) {
        complete(const AdSenseOverlayResult.loaded());
      } else {
        complete(const AdSenseOverlayResult.dismissed());
      }
    }).toJS;

    closeButton.addEventListener('click', closeListener);

    return completer.future.whenComplete(() {
      closeButton.removeEventListener('click', closeListener);
      timeoutTimer?.cancel();
      observer.disconnect();
    });
  }

  void removeElementById(String elementId) {
    final element = web.document.getElementById(elementId);
    element?.remove();
  }
}
