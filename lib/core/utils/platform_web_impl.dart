// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

void platformRedirectTo(String url) {
  try {
    html.window.location.href = url;
  } catch (_) {}
}

String platformGetUrlFragment() {
  try {
    final hash = html.window.location.hash;
    return hash;
  } catch (_) {
    return '';
  }
}

void platformClearUrlFragment() {
  try {
    final pathname = html.window.location.pathname ?? '/';
    html.window.history.replaceState(null, '', pathname);
  } catch (_) {}
}

Future<String?> platformPickImageAsBase64({
  int maxDimension = 512,
  double quality = 0.85,
  bool fromCamera = false,
}) async {
  final completer = Completer<String?>();

  try {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    if (fromCamera) {
      uploadInput.setAttribute('capture', 'user');
    }
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);

      reader.onLoadEnd.listen((_) {
        final rawDataUrl = reader.result?.toString();
        if (rawDataUrl == null || rawDataUrl.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        // Scale & compress using Canvas to prevent large memory/storage footprint
        final imageElement = html.ImageElement();
        imageElement.src = rawDataUrl;

        imageElement.onLoad.listen((_) {
          try {
            int width = imageElement.width ?? 0;
            int height = imageElement.height ?? 0;

            if (width <= 0 || height <= 0) {
              if (!completer.isCompleted) completer.complete(rawDataUrl);
              return;
            }

            // Calculate scaled dimensions
            if (width > maxDimension || height > maxDimension) {
              if (width > height) {
                height = (height * (maxDimension / width)).round();
                width = maxDimension;
              } else {
                width = (width * (maxDimension / height)).round();
                height = maxDimension;
              }
            }

            final canvas = html.CanvasElement(width: width, height: height);
            final ctx = canvas.context2D;
            ctx.drawImageScaled(imageElement, 0, 0, width, height);

            final compressedDataUrl = canvas.toDataUrl('image/jpeg', quality);
            if (!completer.isCompleted) completer.complete(compressedDataUrl);
          } catch (_) {
            if (!completer.isCompleted) completer.complete(rawDataUrl);
          }
        });

        imageElement.onError.listen((_) {
          if (!completer.isCompleted) completer.complete(rawDataUrl);
        });
      });

      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });
  } catch (e) {
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}

html.WindowBase? _activeOAuthPopup;
Completer<String?>? _activeOAuthCompleter;
StreamSubscription? _messageSubscription;
Timer? _popupCheckTimer;

Future<String?> platformOpenOAuthPopup(String url) {
  // If there's already a popup open, close it first
  platformCloseOAuthPopup();

  final completer = Completer<String?>();
  _activeOAuthCompleter = completer;

  try {
    final screenWidth = html.window.screen?.width ?? 1024;
    final screenHeight = html.window.screen?.height ?? 768;
    const width = 500;
    const height = 650;
    final left = (screenWidth - width) ~/ 2;
    final top = (screenHeight - height) ~/ 2;

    final popup = html.window.open(
      url,
      'CineAIGoogleAuth',
      'width=$width,height=$height,left=$left,top=$top,menubar=no,toolbar=no,status=no,resizable=yes,scrollbars=yes',
    );
    _activeOAuthPopup = popup;

    // Listen for postMessage from the popup window
    _messageSubscription = html.window.onMessage.listen((event) {
      try {
        final data = event.data;
        if (data is Map && data['type'] == 'CINEAI_OAUTH_RESPONSE') {
          final hash = data['hash']?.toString();
          _cleanupOAuthPopup();
          if (!completer.isCompleted) completer.complete(hash);
        } else if (data is String && data.contains('access_token=')) {
          _cleanupOAuthPopup();
          if (!completer.isCompleted) completer.complete(data);
        }
      } catch (_) {}
    });

    // Check periodically if user closed popup manually or if it navigated back
    _popupCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      try {
        if (_activeOAuthPopup == null || _activeOAuthPopup!.closed == true) {
          _cleanupOAuthPopup();
          if (!completer.isCompleted) completer.complete(null);
        }
      } catch (_) {
        _cleanupOAuthPopup();
        if (!completer.isCompleted) completer.complete(null);
      }
    });
  } catch (e) {
    _cleanupOAuthPopup();
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}

void platformCloseOAuthPopup() {
  try {
    if (_activeOAuthPopup != null && _activeOAuthPopup!.closed != true) {
      _activeOAuthPopup!.close();
    }
  } catch (_) {}
  _cleanupOAuthPopup();
  if (_activeOAuthCompleter != null && !_activeOAuthCompleter!.isCompleted) {
    _activeOAuthCompleter!.complete(null);
  }
}

void _cleanupOAuthPopup() {
  _popupCheckTimer?.cancel();
  _popupCheckTimer = null;
  _messageSubscription?.cancel();
  _messageSubscription = null;
  _activeOAuthPopup = null;
}

void platformOpenInNewTab(String url) {
  try {
    html.window.open(url, '_blank');
  } catch (_) {}
}

Future<void> platformDownloadFile(String content, String fileName, {String mimeType = 'application/json'}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    // Fallback: Data URI
    try {
      final encoded = Uri.encodeComponent(content);
      final anchor = html.AnchorElement(href: 'data:$mimeType;charset=utf-8,$encoded')
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {}
  }
}

Future<String?> platformPickTextFile({String accept = '.json,application/json'}) async {
  final completer = Completer<String?>();
  try {
    final uploadInput = html.FileUploadInputElement()..accept = accept;
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoadEnd.listen((_) {
        final text = reader.result?.toString();
        if (!completer.isCompleted) completer.complete(text);
      });
      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}
