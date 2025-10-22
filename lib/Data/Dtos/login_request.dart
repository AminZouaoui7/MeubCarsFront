// lib/features/auth/data/dtos/login_request.dart
class LoginRequest {
  final String cin;
  final String motDePasse;

  LoginRequest({required this.cin, required this.motDePasse});

  Map<String, dynamic> toJson() => {
    "cin": cin,
    "motDePasse": motDePasse,
  };
}
