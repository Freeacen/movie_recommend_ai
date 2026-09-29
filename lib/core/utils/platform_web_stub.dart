import 'dart:convert';
import 'package:image_picker/image_picker.dart';

void platformRedirectTo(String url) {}

String platformGetUrlFragment() => '';

void platformClearUrlFragment() {}

Future<String?> platformPickImageAsBase64({
  int maxDimension = 512,
  double quality = 0.85,
  bool fromCamera = false,
}) async {
  try {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: (quality * 100).round(),
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    String mimeType = 'image/jpeg';
    final lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (lowerName.endsWith('.webp')) {
      mimeType = 'image/webp';
    }
    final base64String = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64String';
  } catch (_) {
    return null;
  }
}

Future<String?> platformOpenOAuthPopup(String url) async => null;

void platformCloseOAuthPopup() {}

void platformOpenInNewTab(String url) {}

Future<void> platformDownloadFile(String content, String fileName, {String mimeType = 'application/json'}) async {}

Future<String?> platformPickTextFile({String accept = '.json,application/json'}) async => null;
