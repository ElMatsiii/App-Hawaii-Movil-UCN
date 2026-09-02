import 'package:dio/dio.dart';

/// Jerarquía de errores de la app.
/// Cada feature puede crear sus propias subclases si necesita más detalle.
sealed class AppError {
  final String message;
  const AppError(this.message);
}

/// Error de red (sin conexión, timeout, etc.)
final class NetworkError extends AppError {
  const NetworkError([super.message = 'Sin conexión a internet']);
}

/// El servidor respondió pero con un error en el JSON.
final class ServerError extends AppError {
  final int? statusCode;
  const ServerError(super.message, {this.statusCode});
}

/// Credenciales inválidas.
final class AuthError extends AppError {
  const AuthError([super.message = 'Usuario o contraseña incorrectos']);
}

/// Error desconocido.
final class UnknownError extends AppError {
  const UnknownError([super.message = 'Error inesperado']);
}

/// Convierte un [DioException] en un [AppError] tipado.
AppError dioToAppError(DioException e) {
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      const NetworkError(
        'El servidor UCN no respondió a tiempo. Verifica si requieres la red/VPN del campus.',
      ),
    DioExceptionType.connectionError => const NetworkError(
        'No se pudo conectar con el servidor UCN (losvilos.ucn.cl). Verifica si requieres la red/VPN institucional o si el servidor está inactivo.',
      ),
    DioExceptionType.badResponse => ServerError(
        _extractServerMessage(e),
        statusCode: e.response?.statusCode,
      ),
    _ => const UnknownError(),
  };
}

String _extractServerMessage(DioException e) {
  try {
    final data = e.response?.data;
    if (data is Map && data['mensaje'] != null) {
      return data['mensaje'] as String;
    }
  } catch (_) {}
  return 'Error del servidor (${e.response?.statusCode})';
}
