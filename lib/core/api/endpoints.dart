// lib/core/api/endpoints.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// 🌐 Centralized base URL configuration for all platforms
  class EndPoint {
  static String get baseUrl {
    try {
      // 🕸️ Flutter Web → Always Render API
      if (kIsWeb) {
        return "https://meubcars-api.onrender.com/api/";
      }

      // 🤖 Android emulator (local dev)
      if (defaultTargetPlatform == TargetPlatform.android) {
        return "http://10.0.2.2:5282/api/";
      }

      // 💻 iOS / macOS / Windows (local dev)
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) {
        return "http://localhost:5282/api/";
      }
    } catch (e) {
      // ✅ Defensive: avoid crash on web if Platform access fails
      print("⚠️ Platform detection failed: $e");
    }

    // 🌍 Fallback — safe default for any environment
    return "https://meubcars-api.onrender.com/api/";
  }
}
