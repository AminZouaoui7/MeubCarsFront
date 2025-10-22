import 'dart:convert';
import 'package:meubcars/Data/Models/user_model.dart';

class LoginResponse {
  final String token;
  final UserModel? user; // may be null if backend returns token only

  LoginResponse({required this.token, this.user});

  factory LoginResponse.fromAny(dynamic raw) {
    final map = _asJsonMap(raw);

    final token = (map['token'] ?? map['accessToken'])?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Login payload missing token');
    }

    Map<String, dynamic>? userMap;
    if (map['user'] is Map<String, dynamic>) {
      userMap = (map['user'] as Map).cast<String, dynamic>();
    } else if (map.keys.toString().contains('nomComplet')) {
      userMap = {
        'id': map['id'],
        'nomComplet': map['nomComplet'],
        'email': map['email'],
        'telephone': map['telephone'],
        'cin': map['cin'],
        'role': map['role'],
        'societeId': map['societeId'],
      };
    }

    return LoginResponse(
      token: token,
      user: userMap == null ? null : UserModel.fromJson(userMap),
    );
  }

  static Map<String, dynamic> _asJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) return d;
      return {'token': raw}; // bare token string
    }
    if (raw is List<int>) {
      final d = jsonDecode(utf8.decode(raw));
      if (d is Map<String, dynamic>) return d;
    }
    throw const FormatException('Unexpected login response type');
  }
}
