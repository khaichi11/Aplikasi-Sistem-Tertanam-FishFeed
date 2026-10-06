import 'package:firebase_core/firebase_core.dart';

/// Konfigurasi Firebase dibaca dari `--dart-define` atau
/// `--dart-define-from-file=firebase.json`, sehingga tidak ada kunci API di
/// repositori. Bila belum diisi, aplikasi berjalan dalam mode demo.
abstract final class FirebaseConfig {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Paksa mode demo walaupun Firebase sudah dikonfigurasi.
  static const forceDemo = bool.fromEnvironment('FISHFEED_DEMO');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _databaseUrl.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: _projectId,
    databaseURL: _databaseUrl,
    iosBundleId: _iosBundleId.isEmpty ? null : _iosBundleId,
  );
}
