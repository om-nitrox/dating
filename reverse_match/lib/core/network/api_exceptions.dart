class AppException implements Exception {
  final String message;
  final int? statusCode;

  AppException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'No internet connection']) : super(message);
}

class ServerException extends AppException {
  ServerException(String message, [int? statusCode])
      : super(message, statusCode);
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized']) : super(message, 401);
}

class TimeoutException extends AppException {
  TimeoutException([String message = 'Request timed out']) : super(message);
}
