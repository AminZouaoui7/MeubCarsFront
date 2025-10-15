// features/auth/logic/auth_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:meubcars/Data/Dtos/login_response.dart';
import 'package:meubcars/Data/repositories/auth_repository.dart';


class AuthViewModel extends ChangeNotifier {
  final IAuthRepository repo;
  AuthViewModel(this.repo);

  bool loading = false;
  String? error;
  LoginResponse? lastLogin;

  Future<bool> login(String cin, String motDePasse) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final res = await repo.login(cin, motDePasse);
      lastLogin = res;           // ✅ no cast
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
