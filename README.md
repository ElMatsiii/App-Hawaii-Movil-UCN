# Hawaii UCN — App Móvil

Aplicación móvil Android para el sistema académico Hawaii de la Universidad Católica del Norte, Sede Coquimbo. Construida con Flutter, consume la API REST de Hawaii y sigue una arquitectura por features con separación estricta de capas.

---

## Tabla de contenidos

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración de la API](#configuración-de-la-api)
- [Funcionalidades](#funcionalidades)
- [Arquitectura](#arquitectura)
- [Build de release](#build-de-release)
- [Comandos de desarrollo](#comandos-de-desarrollo)
- [Seguridad](#seguridad)

---

## Requisitos

| Herramienta         | Versión mínima | Referencia                                        |
|---------------------|----------------|---------------------------------------------------|
| Flutter SDK         | 3.19           | https://flutter.dev/docs/get-started/install      |
| Dart SDK            | 3.2            | Incluido con Flutter                              |
| Android Studio      | Hedgehog+      | Para emulador y SDK Manager                       |

Verificar el entorno antes de continuar:

```bash
flutter doctor
```

---

## Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/ElMatsiii/Proyecto-Integrador-De-Plataformas.git
cd Proyecto-Integrador-De-Plataformas

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en modo debug (ambiente de desarrollo por defecto)
flutter run
```

---

## Configuración de la API

La URL base de la API se inyecta en tiempo de compilación mediante `--dart-define`. Si no se especifica, la app usa el ambiente de desarrollo.

| Ambiente     | URL                                   |
|--------------|---------------------------------------|
| Desarrollo   | `https://losvilos.ucn.cl/hawaii`      |
| Producción   | `https://losvilos.ucn.cl/tongoy`      |

```bash
# Desarrollo (por defecto)
flutter run

# Producción
flutter run --dart-define=API_BASE_URL=https://losvilos.ucn.cl/tongoy
flutter build apk --release --dart-define=API_BASE_URL=https://losvilos.ucn.cl/tongoy
```

### Endpoints disponibles

| Endpoint                  | Método | Autenticación | Descripción                         |
|---------------------------|--------|---------------|-------------------------------------|
| `/master.php`             | GET    | No            | Áreas, bloques, salas, semestres    |
| `/g.php`                  | GET    | No            | Horario con filtros                 |
| `/a.php?op=auth`          | POST   | No            | Login con credenciales UCN          |
| `/a.php` + param `tg`     | POST   | No            | Login con token OAuth de Google     |
| `/mi.php`                 | GET    | Cookie        | Datos del usuario autenticado       |
| `/cp.php`                 | GET    | Cookie        | Cursos del usuario en el semestre   |
| `/notas-estudiante.php`   | GET    | Cookie        | Notas por curso                     |
| `/asist_marcar6.php`      | GET    | Cookie        | Lista de asistencia por curso       |
| `/asist_marcar6.php?op=s` | POST   | Cookie        | Guardar marca de asistencia         |
| `/ge.php`                 | POST   | No            | Validar RUT de estudiante           |

La sesión se mantiene mediante cookie `PHPSESSID` gestionada automáticamente por `dio_cookie_manager`.

---

## Funcionalidades

**Horario**
Consulta el horario de clases de cualquier carrera, con filtros por área, docente y sala. Accesible sin iniciar sesión.

**Mis cursos**
Lista los cursos inscritos en el semestre activo junto con las notas parciales y finales de cada uno. Requiere sesión.

**Asistencia**
Visualiza el porcentaje de asistencia por curso. Incluye escáner QR para marcar asistencia en clases presenciales; el validador acepta únicamente URLs del endpoint de asistencia conocido. Requiere sesión.

**Autenticación**
Soporta login con credenciales UCN (RUT y contraseña) y login con cuenta Google del dispositivo. La sesión se persiste de forma segura entre reinicios de la app.

**Accesibilidad**
Panel de ajustes con selección de color seed del tema (paleta predefinida de 10 colores, con soporte Material You claro y oscuro), modo daltónico con paleta Okabe-Ito, y control de escala de fuente.

**Notificaciones**
Soporte para notificaciones locales de horario mediante `flutter_local_notifications`.

---

## Arquitectura

El proyecto sigue una estructura por features. Cada feature tiene sus propias capas de datos, dominio y presentación, sin dependencias cruzadas entre features.

```
lib/
├── main.dart
├── core/
│   ├── constants/          # ApiConstants, StorageKeys, FeatureFlags
│   ├── errors/             # AppError, Result<T>
│   ├── network/            # DioClient (singleton lazy con cookie jar)
│   ├── router/             # GoRouter, AppRoutes, redirect guard
│   ├── services/           # NotificacionesService
│   └── utils/              # json_read, text_normalize
├── features/
│   ├── auth/
│   │   ├── data/           # AuthRemoteDatasource, GoogleAuthService, AuthRepository
│   │   ├── domain/         # UsuarioEntity, IAuthRepository, use cases
│   │   └── presentation/   # AuthNotifier (StateNotifier), LoginScreen
│   ├── horario/
│   │   ├── data/           # HorarioDatasource, HorarioDTO, HorarioRepository
│   │   ├── domain/         # HorarioEntity, IHorarioRepository, use cases
│   │   └── presentation/   # HorarioNotifier, HorarioScreen, widgets
│   ├── mis_cursos/
│   │   ├── data/           # MisCursosDatasource, NotasDatasource
│   │   ├── domain/         # CursoUsuarioEntity, NotasEntities
│   │   └── presentation/   # MisCursosScreen
│   └── asistencia/
│       ├── data/           # AsistenciaDatasource
│       ├── domain/         # QrAsistenciaValidator
│       └── presentation/   # AsistenciaScreen, AsistenciaCourseList,
│                           # AsistenciaDetail, QrScannerSheet
└── shared/
    ├── providers/          # ShellNavigationProvider
    ├── settings/           # AccessibilitySettings (Riverpod + SharedPreferences)
    ├── theme/              # AppTheme, AppColors, AttendanceStateColors
    └── widgets/            # MainScaffold, AccessibilitySettingsButton, LogoutButton
```

**Decisiones técnicas relevantes**

- Estado global con Riverpod (`StateNotifierProvider`, `Provider`). El router escucha `authProvider` mediante un `ChangeNotifier` puente.
- Navegación con GoRouter y `StatefulShellRoute.indexedStack` para mantener el estado de cada tab entre cambios de pestaña.
- Invalidación centralizada de providers al cambiar de cuenta dentro de `AuthNotifier`, para evitar que datos de una sesión anterior persistan en otra.

---

## Build de release

### 1. Crear el keystore

```bash
keytool -genkeypair -v \
  -keystore android/keystore/tongoy-release.jks \
  -alias tongoy \
  -keyalg RSA -keysize 2048 -validity 10000
```

### 2. Crear `android/keystore.properties`

```properties
storeFile=../keystore/tongoy-release.jks
storePassword=TU_STORE_PASSWORD
keyAlias=tongoy
keyPassword=TU_KEY_PASSWORD
```

El archivo `keystore.properties` y el `.jks` están en `.gitignore`. No deben subirse al repositorio bajo ninguna circunstancia.

### 3. Compilar

```bash
# APK universal
flutter build apk --release --dart-define=API_BASE_URL=https://losvilos.ucn.cl/tongoy

# APKs por ABI (menor tamaño de descarga)
flutter build apk --split-per-abi --release --dart-define=API_BASE_URL=https://losvilos.ucn.cl/tongoy
```

---

## Comandos de desarrollo

```bash
flutter pub get           # Instalar dependencias
flutter test              # Ejecutar tests
flutter analyze           # Análisis estático
dart format lib/ test/    # Formatear código
flutter build apk --debug # APK de debug sin keystore
```

---

## Seguridad

- La cookie de sesión (`PHPSESSID`) es manejada por `dio_cookie_manager` y persiste en disco usando `flutter_secure_storage` con cifrado nativo del dispositivo.
- El validador QR comprueba dominio y ruta del endpoint antes de procesar cualquier URL escaneada; rechaza cualquier URL que no corresponda al endpoint de asistencia conocido.
- En Android, `usesCleartextTraffic="false"` está activo, lo que fuerza HTTPS en todas las conexiones de red.
- No se registran datos personales, tokens ni cookies en los logs de producción.
- Los controles de autorización del lado del servidor (IDOR, expiración de tokens QR, validez de sesión) están documentados en `docs/security-backend-checklist.md` y deben verificarse en el backend de Hawaii antes de un despliegue a producción.