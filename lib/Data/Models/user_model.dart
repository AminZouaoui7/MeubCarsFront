// features/auth/data/models/user_model.dart
class UserModel {
  final int id;
  final String nomComplet;
  final String? email;
  final String? telephone;
  final String cin;
  final String role;
  final int? societeId;

  const UserModel({
    required this.id,
    required this.nomComplet,
    this.email,
    this.telephone,
    required this.cin,
    required this.role,
    this.societeId,
  });

  /// Robust int parser (accepts int, num, "1", null)
  static int _asInt(dynamic v, {int? def}) {
    if (v == null) return def ?? 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty || t.toLowerCase() == 'null') return def ?? 0;
      return int.tryParse(t) ?? (def ?? 0);
    }
    return def ?? 0;
  }

  /// Robust string parser
  static String? _asStringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
  }

  /// Some backends send slightly different keys. We handle a few aliases.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleRaw = json['role'] ?? json['Role'];
    // role might be an enum/int; turn into string
    final roleStr = roleRaw is num ? roleRaw.toInt().toString() : (roleRaw?.toString() ?? '');

    return UserModel(
      id: _asInt(json['id'] ?? json['Id'], def: 0),
      nomComplet: (_asStringOrNull(json['nomComplet']) ??
          _asStringOrNull(json['fullName']) ??
          _asStringOrNull(json['name']) ??
          '')!,
      email: _asStringOrNull(json['email'] ?? json['Email']),
      telephone: _asStringOrNull(json['telephone'] ?? json['phone']),
      cin: (_asStringOrNull(json['cin']) ?? '')!,
      role: roleStr,
      societeId: (json.containsKey('societeId') || json.containsKey('SocieteId'))
          ? _asInt(json['societeId'] ?? json['SocieteId'], def: 0)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nomComplet': nomComplet,
    'email': email,
    'telephone': telephone,
    'cin': cin,
    'role': role,
    'societeId': societeId,
  };

  UserModel copyWith({
    int? id,
    String? nomComplet,
    String? email,
    String? telephone,
    String? cin,
    String? role,
    int? societeId,
  }) {
    return UserModel(
      id: id ?? this.id,
      nomComplet: nomComplet ?? this.nomComplet,
      email: email ?? this.email,
      telephone: telephone ?? this.telephone,
      cin: cin ?? this.cin,
      role: role ?? this.role,
      societeId: societeId ?? this.societeId,
    );
  }

  /// Handy for avatars
  String get initials {
    final parts = nomComplet.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'UT';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
