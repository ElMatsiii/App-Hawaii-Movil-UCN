import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/json_read.dart';
import '../../domain/entities/usuario_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
 
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authRemoteDataSourceProvider),
    const FlutterSecureStorage(),
  );
});
 
const _kCookieKey = 'phpsessid_cookie';
const _kLoginViaGoogleKey = 'login_via_google';
const _kSessionDuration = Duration(days: 7);
 
class AuthRepository implements IAuthRepository {
  final AuthRemoteDataSource _remote;
  final FlutterSecureStorage _storage;
 
  const AuthRepository(this._remote, this._storage);
 
  @override
  Future<Result<UsuarioEntity>> login(
    String usuario,
    String password,
  ) async {
    final loginResult = await _remote.login(usuario, password);
    if (loginResult is Failure) return Failure(loginResult.errorOrNull!);
 
    await _storage.write(key: StorageKeys.usuario, value: usuario);
    await _storage.write(
      key: StorageKeys.loginAt,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    await _storage.delete(key: _kLoginViaGoogleKey);
    await _persistCookie();
 
    return getUsuarioActual();
  }
 
  @override
  Future<Result<UsuarioEntity>> loginConGoogle(String accessToken) async {
    final loginResult = await _remote.loginConGoogle(accessToken);
    if (loginResult is Failure) return Failure(loginResult.errorOrNull!);
 
    await _storage.write(key: _kLoginViaGoogleKey, value: 'true');
    await _storage.write(
      key: StorageKeys.loginAt,
      value: DateTime.now().toUtc().toIso8601String(),
    );
    await _persistCookie();
 
    final usuarioResult = await getUsuarioActual();
    if (usuarioResult is Success<UsuarioEntity>) {
      await _storage.write(
        key: StorageKeys.usuario,
        value: usuarioResult.data.rut,
      );
    }
    return usuarioResult;
  }
 
  @override
  Future<Result<void>> logout() async {
    try {
      await Future.wait([
        _storage.delete(key: StorageKeys.usuario),
        _storage.delete(key: StorageKeys.loginAt),
        _storage.delete(key: _kCookieKey),
        _storage.delete(key: _kLoginViaGoogleKey),
      ]);
      await DioClient.cookieJar.deleteAll();
      return const Success(null);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }
 
  @override
  Future<Result<UsuarioEntity>> getUsuarioActual() async {
    final result = await _remote.getUsuarioActual();
    return result.when(
      success: (data) => Success(
        UsuarioEntity(rut: data['rut']!, nombre: data['nombre']!),
      ),
      failure: (e) => Failure(e),
    );
  }
 
  @override
  Future<bool> estaAutenticado() async {
    final usuario = await _storage.read(key: StorageKeys.usuario);
    if (usuario == null) return false;

    // Verificar que la sesión no haya expirado (máximo 7 días).
    final loginAtRaw = await _storage.read(key: StorageKeys.loginAt);
    if (loginAtRaw != null) {
      final loginAt = DateTime.tryParse(loginAtRaw);
      if (loginAt != null) {
        final expiry = loginAt.toUtc().add(_kSessionDuration);
        if (DateTime.now().toUtc().isAfter(expiry)) {
          await logout();
          return false;
        }
      }
    }

    final cookieRestaurada = await _restoreCookie();
    if (!cookieRestaurada) {
      await logout();
      return false;
    }

    return true;
  }
 
  Future<void> _persistCookie() async {
    try {
      final uri = Uri.parse(ApiConstants.baseUrl);
      final cookies = await DioClient.cookieJar.loadForRequest(uri);
      final session = cookies.firstWhere(
        (c) => c.name == 'PHPSESSID',
        orElse: () => Cookie('', ''),
      );
      if (session.value.isEmpty) return;
      final payload = <String, dynamic>{
        'name': session.name,
        'value': session.value,
        'domain': session.domain,
        'path': session.path,
        'expires': session.expires?.toIso8601String(),
        'secure': session.secure,
        'httpOnly': session.httpOnly,
      };
 
      await _storage.write(key: _kCookieKey, value: jsonEncode(payload));
    } catch (_) {
      // La sesion en memoria sigue funcionando; se pedira login al reiniciar.
    }
  }
 
  Future<bool> _restoreCookie() async {
    try {
      final raw = await _storage.read(key: _kCookieKey);
      if (raw == null || raw.isEmpty) return false;
 
      final cookie = _cookieFromStoredValue(raw);
      if (cookie == null || cookie.value.isEmpty) return false;
 
      final now = DateTime.now().toUtc();
      if (cookie.expires != null && cookie.expires!.toUtc().isBefore(now)) {
        await _storage.delete(key: _kCookieKey);
        return false;
      }
 
      final uri = Uri.parse(ApiConstants.baseUrl);
      await DioClient.cookieJar.saveFromResponse(uri, [cookie]);
      return true;
    } catch (_) {
      return false;
    }
  }
 
  Cookie? _cookieFromStoredValue(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final data = decoded.map((key, value) => MapEntry(key.toString(), value));
      final name = readString(data['name']);
      final value = readString(data['value']);
      if (name.isEmpty || value.isEmpty) return null;
 
      final expiresRaw = readString(data['expires']);
      return Cookie(name, value)
        ..domain = readString(
          data['domain'],
          fallback: Uri.parse(ApiConstants.baseUrl).host,
        )
        ..path = readString(data['path'], fallback: '/')
        ..expires = expiresRaw.isEmpty ? null : DateTime.tryParse(expiresRaw)
        ..secure = readBool(data['secure'], fallback: true)
        ..httpOnly = readBool(data['httpOnly'], fallback: true);
    }
 
    if (!raw.contains('=')) return null;
    final parts = raw.split('=');
    return Cookie(parts.first, parts.sublist(1).join('='))
      ..domain = Uri.parse(ApiConstants.baseUrl).host
      ..path = '/'
      ..secure = true
      ..httpOnly = true;
  }
}