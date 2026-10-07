/// Opens the app's SQLite database: a file on the phone (and on Windows),
/// or browser storage when the app runs in Chrome during development.
library;

export 'native.dart' if (dart.library.js_interop) 'web.dart';
