import 'platform_web_stub.dart'
    if (dart.library.html) 'platform_web_impl.dart';

class PlatformWebHelper {
  /// Redirect the browser window to a target URL (e.g. Supabase Google OAuth)
  static void redirectTo(String url) {
    platformRedirectTo(url);
  }

  /// Get the current URL fragment/hash (e.g. #access_token=...&refresh_token=...)
  static String getUrlFragment() {
    return platformGetUrlFragment();
  }

  /// Clear the URL fragment/hash from the browser location bar without reloading
  static void clearUrlFragment() {
    platformClearUrlFragment();
  }

  /// Pick an image file from the device/filesystem and return it as a compressed base64 data URL
  static Future<String?> pickImageAsBase64({int maxDimension = 512, double quality = 0.85}) {
    return platformPickImageAsBase64(maxDimension: maxDimension, quality: quality);
  }

  /// Open OAuth in a centered popup window and await the returned token hash
  static Future<String?> openOAuthPopup(String url) {
    return platformOpenOAuthPopup(url);
  }

  /// Close any active OAuth popup window
  static void closeOAuthPopup() {
    platformCloseOAuthPopup();
  }

  /// Open a URL in a new browser tab/window
  static void openInNewTab(String url) {
    platformOpenInNewTab(url);
  }

  /// Download text content as a file to the user's filesystem
  static Future<void> downloadFile(String content, String fileName, {String mimeType = 'application/json'}) {
    return platformDownloadFile(content, fileName, mimeType: mimeType);
  }

  /// Pick a text/json file from the device/filesystem and return its text content
  static Future<String?> pickTextFile({String accept = '.json,application/json'}) {
    return platformPickTextFile(accept: accept);
  }
}
