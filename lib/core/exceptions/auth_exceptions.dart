/// Excepciones relacionadas con autenticación
class EmailConfirmationRequiredException implements Exception {
  const EmailConfirmationRequiredException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class UserNotFoundException implements Exception {
  const UserNotFoundException(this.message);
  final String message;

  @override
  String toString() => message;
}
