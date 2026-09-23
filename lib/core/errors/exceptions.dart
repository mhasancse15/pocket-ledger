/// Core exceptions and error handling
class AppException implements Exception {
  final String message;
  final dynamic originalException;
  final StackTrace? stackTrace;

  AppException({
    required this.message,
    this.originalException,
    this.stackTrace,
  });

  @override
  String toString() => message;
}

class DatabaseException extends AppException {
  DatabaseException({required super.message, super.originalException, super.stackTrace});
}

class CacheException extends AppException {
  CacheException({required super.message, super.originalException, super.stackTrace});
}

class FileException extends AppException {
  FileException({required super.message, super.originalException, super.stackTrace});
}
