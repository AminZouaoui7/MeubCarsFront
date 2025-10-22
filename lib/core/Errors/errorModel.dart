class ErrorModel {
  final bool status;
  final String errorMessage;

  ErrorModel({
    required this.status,
    required this.errorMessage,
  });

  factory ErrorModel.fromJson(Map<String, dynamic>? json) {
    return ErrorModel(
      status: json?['status'] == true,
      errorMessage: json?['errorMessage']?.toString() ?? 'Erreur inconnue',
    );
  }

}


