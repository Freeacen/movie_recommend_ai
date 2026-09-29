void platformRedirectTo(String url) {}

String platformGetUrlFragment() => '';

void platformClearUrlFragment() {}

Future<String?> platformPickImageAsBase64({int maxDimension = 512, double quality = 0.85}) async {
  return null;
}

Future<String?> platformOpenOAuthPopup(String url) async => null;

void platformCloseOAuthPopup() {}

void platformOpenInNewTab(String url) {}

Future<void> platformDownloadFile(String content, String fileName, {String mimeType = 'application/json'}) async {}

Future<String?> platformPickTextFile({String accept = '.json,application/json'}) async => null;
