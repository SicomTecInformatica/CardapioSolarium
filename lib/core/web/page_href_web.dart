import 'dart:js_interop';

@JS('window.location.href')
external String get _locationHref;

String pageHref() => _locationHref;
