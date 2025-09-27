import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

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
}
