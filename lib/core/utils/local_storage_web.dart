// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? platformGetStorageItem(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void platformSetStorageItem(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}
