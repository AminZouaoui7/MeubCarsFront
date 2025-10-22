import 'dart:convert';

import 'package:meubcars/Data/Dtos/login_response.dart';
import 'package:meubcars/core/cache/CacheHelper.dart';
import 'package:meubcars/Data/Models/user_model.dart';
import 'package:meubcars/Data/remote/auth_remote.dart';

abstract class IAuthRepository {
  Future<LoginResponse> login(String cin, String motDePasse);
  Future<void> logout();
  Future<bool> hasToken();
  Future<UserModel?> getCachedUser();
}

class AuthRepository implements IAuthRepository {
  final AuthRemote remote;
  AuthRepository(this.remote);

  static const _kTokenKey = 'token';
  static const _kUserKey  = 'user';

  @override
  Future<LoginResponse> login(String cin, String motDePasse) async {
    final resp = await remote.login(cin: cin, motDePasse: motDePasse);
    await CacheHelper.saveData(key: _kTokenKey, value: resp.token);

    UserModel? user = resp.user;

    // If backend only returned token, try to fill user
    if (user == null) {
      try {
        final me = await remote.me(resp.token);
        user = UserModel.fromJson(me);
      } catch (_) {
        final id = _tryDecodeUserId(resp.token);
        if (id != null) {
          final u = await remote.getUserById(resp.token, id);
          user = UserModel.fromJson(u);
        }
      }
    }

    if (user == null) {
      throw const FormatException('Impossible de récupérer l’utilisateur');
    }

    // Save compact JSON
    await CacheHelper.saveData(
      key: _kUserKey,
      value: jsonEncode({
        'id': user.id,
        'nomComplet': user.nomComplet,
        'email': user.email,
        'telephone': user.telephone,
        'cin': user.cin,
        'role': user.role,
        'societeId': user.societeId,
      }),
    );

    // Also save individual fields (many widgets use them)
    await CacheHelper.saveData(key: 'userId', value: user.id);
    await CacheHelper.saveData(key: 'userName', value: user.nomComplet ?? 'Utilisateur');
    await CacheHelper.saveData(key: 'nomComplet', value: user.nomComplet ?? 'Utilisateur');
    await CacheHelper.saveData(key: 'email', value: user.email ?? '');
    await CacheHelper.saveData(key: 'telephone', value: user.telephone ?? '');
    await CacheHelper.saveData(key: 'cin', value: user.cin ?? '');
    await CacheHelper.saveData(key: 'role', value: user.role ?? '');
    await CacheHelper.saveData(key: 'societeId', value: user.societeId ?? 0);

    return LoginResponse(token: resp.token, user: user);
  }

  @override
  Future<void> logout() async {
    final token = CacheHelper.getData<String>(key: _kTokenKey) ?? '';
    if (token.isNotEmpty) {
      try {
        await remote.logout(token); // ignore errors
      } catch (_) {}
    }

    // Clear all local auth state
    await CacheHelper.removeData(key: _kTokenKey);
    await CacheHelper.removeData(key: _kUserKey);
    await CacheHelper.removeData(key: 'userId');
    await CacheHelper.removeData(key: 'userName');
    await CacheHelper.removeData(key: 'nomComplet');
    await CacheHelper.removeData(key: 'email');
    await CacheHelper.removeData(key: 'telephone');
    await CacheHelper.removeData(key: 'cin');
    await CacheHelper.removeData(key: 'role');
    await CacheHelper.removeData(key: 'societeId');
  }

  @override
  Future<bool> hasToken() async =>
      (CacheHelper.getData<String>(key: _kTokenKey) ?? '').isNotEmpty;

  @override
  Future<UserModel?> getCachedUser() async {
    final raw = CacheHelper.getData<String>(key: _kUserKey);
    if (raw == null || raw.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(raw));
  }

  // Decode a JWT quickly to find user id if needed
  int? _tryDecodeUserId(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return null;

      String norm(String s) =>
          s.padRight(s.length + (4 - s.length % 4) % 4, '=')
              .replaceAll('-', '+')
              .replaceAll('_', '/');

      final payload = jsonDecode(utf8.decode(base64Url.decode(norm(parts[1]))));
      final dynamic v = payload['nameid'] ?? payload['sub'] ?? payload['id'] ?? payload['userId'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }
}
