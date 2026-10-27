import 'dart:js_interop';

@JS('window.open')
external JSAny? _openWindow(JSString url, JSString target);

bool openSocialPlatform(String platform) {
  final url = switch (platform) {
    'instagram' => 'https://www.instagram.com/',
    'facebook' => 'https://www.facebook.com/',
    'linkedin' => 'https://www.linkedin.com/feed/',
    _ => null,
  };
  if (url == null) return false;
  _openWindow(url.toJS, '_blank'.toJS);
  return true;
}

bool openUrlInCurrentTab(String url) {
  _openWindow(url.toJS, '_self'.toJS);
  return true;
}
