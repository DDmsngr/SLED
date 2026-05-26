/// Единый тип ошибок приложения.
sealed class AppError implements Exception {
  const AppError(this.message);
  final String message;

  @override
  String toString() => 'AppError($message)';
}

/// Ошибки геолокации.
class LocationError extends AppError {
  const LocationError(super.message);
}

/// Ошибки работы с фото.
class PhotoError extends AppError {
  const PhotoError(super.message);
}

/// Ошибки хранилища.
class StorageError extends AppError {
  const StorageError(super.message);
}

/// Ошибки экспорта.
class ExportError extends AppError {
  const ExportError(super.message);
}
