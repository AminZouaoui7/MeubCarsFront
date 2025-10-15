// lib/core/api/endpoints.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class EndPoint {
  // ==========================================================
  // 🔹 Base URL dynamique selon la plateforme
  // ==========================================================
  static String get baseUrl {
    // 🌍 Cas Web → utilise ton backend Render
    if (kIsWeb) return "https://meubcars-api.onrender.com/api/";

    // 🤖 Android (simulateur/emulateur)
    if (Platform.isAndroid) return "http://10.0.2.2:5282/api/";

    // 💻 iOS ou Desktop (développement local)
    if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
      return "http://localhost:5282/api/";
    }

    // 🌐 Fallback par défaut (production)
    return "https://meubcars-api.onrender.com/api/";
  }

  // ==========================================================
  // 🔹 Endpoints spécifiques
  // ==========================================================
  static const String login = "Auth/login";
  static const String voitures = "Voitures";
  static const String chauffeurs = "Chauffeur";
  static const String depenses = "Depenses";
  static const String paiements = "Paiements";
  static const String ordresMission = "OrdresMission";
}
