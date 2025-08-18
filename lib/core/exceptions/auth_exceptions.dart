/// Excepciones relacionadas con autenticación
class EmailConfirmationRequiredException implements Exception {
  final String message;
  
  const EmailConfirmationRequiredException(this.message);
  
  @override
  String toString() => message;
}

class AuthenticationException implements Exception {
  final String message;
  
  const AuthenticationException(this.message);
  
  @override
  String toString() => message;
}

class UserNotFoundException implements Exception {
  final String message;
  
  const UserNotFoundException(this.message);
  
  @override
  String toString() => message;
}