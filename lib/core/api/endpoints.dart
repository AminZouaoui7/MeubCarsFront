// lib/core/api/endpoints.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class EndPoint {
  // ==========================================================
  // 🔹 Base URL dynamique selon la plateforme
  // ==========================================================
  static String get baseUrl {
    // 🌍 Web (Render production)
    if (kIsWeb) return "https://meubcars-api.onrender.com/api/";

    // 🤖 Android emulator (local dev)
    if (Platform.isAndroid) return "http://10.0.2.2:5282/api/";

    // 💻 iOS / Desktop (local dev)
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
      return "http://localhost:5282/api/";
    }

    // 🌐 Fallback prod
    return "https://meubcars-api.onrender.com/api/";
  }

  // ==========================================================

}
