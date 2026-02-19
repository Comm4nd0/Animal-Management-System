/// Platform-agnostic file download/save helper.
///
/// On web: triggers a browser download via dart:html.
/// On mobile/desktop: writes to the app documents directory and
/// optionally shares via share_plus.
///
/// Uses conditional exports so dart:html is never imported on native.
export 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart';
