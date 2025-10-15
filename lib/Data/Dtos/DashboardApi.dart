import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:meubcars/core/api/endpoints.dart';

class DashboardApi {
  // Ex: EndPoint.baseUrl == "https://localhost:7178/api/"
  final String root = EndPoint.baseUrl.endsWith('/')
      ? EndPoint.baseUrl
      : '${EndPoint.baseUrl}/';

  Uri _u(String path) => Uri.parse('$root$path'); // pas de slash initial

  Future<Map<String, int>> getVoituresStats() async {
    final url = _u('voitures/stats'); // => https://localhost:7178/api/voitures/stats
    // debugPrint('GET $url');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Erreur voitures stats: ${res.statusCode}');
    }
    final data = jsonDecode(res.body);
    return {
      'enPanne': (data['enPanne'] ?? 0) as int,
      'enParking': (data['enParking'] ?? 0) as int,
      'total': (data['total'] ?? 0) as int,
    };
  }
  // ← à placer dans la classe DashboardApi (même fichier)
  Future<int> getSaisieCount() async {
    final url = _u('voitures/count/saisie'); // correspond à GET /api/Voitures/count/saisie
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Erreur saisie count: ${res.statusCode}');
    }
    final body = res.body.trim();

    // L'API renvoie normalement un entier 'raw' ; on gère aussi JSON possible.
    try {
      return int.parse(body);
    } catch (_) {
      final parsed = jsonDecode(body);
      if (parsed is int) return parsed;
      if (parsed is Map && parsed['value'] != null) return parsed['value'] as int;
      throw Exception('Format inattendu pour /voitures/count/saisie');
    }
  }


  Future<int> getTotalMissions() async {
    // Attention au nom du contrôleur: OrdresMissionController => /api/OrdresMission/...
    final url = _u('OrdresMission/stats/yearly'); // casse tolérée mais on met la même
    // debugPrint('GET $url');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Erreur missions stats: ${res.statusCode}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    int total = 0;
    for (final row in data) {
      total += (row['count'] ?? 0) as int;
    }
    return total;
  }
}
