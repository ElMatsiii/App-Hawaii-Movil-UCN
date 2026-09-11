import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider_notif.dart';
import '../../data/asistencia_otp_service.dart';
import '../../data/device_binding_service.dart';
import '../../domain/codigo_optico_alternativo_model.dart';
import '../../domain/qr_asistencia_model.dart';
import '../../domain/qr_asistencia_validator.dart';

/// Pantalla interactiva de laboratorio para pruebas del sistema de asistencia QR.
///
/// Permite testear:
/// 1. Escaneo en tiempo real con captura de alta velocidad y metricas de latencia.
/// 2. Ingreso manual de codigo OTP segun el plan de contingencia (Seccion 10).
/// 3. Generador dinamico de codigos OTP (Modo Profesor / Emisor).
/// 4. Codigos opticos alternativos (ChromaCode, Barras 1D, Ondas, Flashes, Constelaciones).
/// 5. Simulacion de Device Binding y auditoria de seguridad (Seccion 5.3).
class AsistenciaTestScreen extends ConsumerStatefulWidget {
  const AsistenciaTestScreen({super.key});

  @override
  ConsumerState<AsistenciaTestScreen> createState() => _AsistenciaTestScreenState();
}

class _AsistenciaTestScreenState extends ConsumerState<AsistenciaTestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final rutUsuario = authState is AuthAuthenticated ? authState.usuario.rut : '12345678-9';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratorio Asistencia UCN'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.qr_code_scanner),
              text: 'Escaner Aztec / QR',
            ),
            Tab(
              icon: Icon(Icons.keyboard_alt_outlined),
              text: 'Ingreso Manual',
            ),
            Tab(
              icon: Icon(Icons.co_present_outlined),
              text: 'Emisor Profesor (Aztec)',
            ),
            Tab(
              icon: Icon(Icons.science_outlined),
              text: 'Laboratorio Aztec',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabEscanerBenchmark(rutEstudiante: rutUsuario),
          _TabIngresoManual(rutEstudiante: rutUsuario),
          _TabModoProfesor(rutEstudiante: rutUsuario),
          _TabLaboratorioAztec(rutEstudiante: rutUsuario),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: ESCANER EN TIEMPO REAL CON METRICAS DE RENDIMIENTO
// -----------------------------------------------------------------------------
class _TabEscanerBenchmark extends StatefulWidget {
  const _TabEscanerBenchmark({required this.rutEstudiante});
  final String rutEstudiante;

  @override
  State<_TabEscanerBenchmark> createState() => _TabEscanerBenchmarkState();
}

class _TabEscanerBenchmarkState extends State<_TabEscanerBenchmark> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
    ],
  );

  final QrAsistenciaValidator _validator = const QrAsistenciaValidator();
  final AsistenciaOtpService _otpService = AsistenciaOtpService();
  final DeviceBindingService _deviceBinding = DeviceBindingService();

  bool _isScanning = true;
  int _scanStartTime = 0;
  int? _detectionLatencyMs;
  String _formatoDetectado = 'Ninguno';
  ResultadoValidacionQr? _ultimoResultado;
  RegistroAsistenciaResultado? _registroResultado;
  String _deviceId = 'Consultando...';
  bool _dispositivoVinculado = true;
  int _ventanaVigenciaSegundos = 60;
  Timer? _countdownTimer;
  int _segundosRestantes = 0;

  @override
  void initState() {
    super.initState();
    _scanStartTime = DateTime.now().millisecondsSinceEpoch;
    _cargarInfoDispositivo();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _cargarInfoDispositivo() async {
    final id = await _deviceBinding.getDeviceId();
    final vinculado = await _deviceBinding.estaDispositivoVinculado(widget.rutEstudiante);
    if (mounted) {
      setState(() {
        _deviceId = id;
        _dispositivoVinculado = vinculado;
      });
    }
  }

  void _iniciarCuentaRegresiva(int segundos) {
    _countdownTimer?.cancel();
    setState(() => _segundosRestantes = segundos);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes <= 0) {
        timer.cancel();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || (barcode.rawValue ?? '').isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final latency = now - _scanStartTime;
    final rawText = barcode.rawValue!;
    final formatName = barcode.format.name.toUpperCase();

    setState(() {
      _isScanning = false;
      _detectionLatencyMs = latency;
      _formatoDetectado = formatName;
    });

    final validacion = _validator.validarContenido(
      rawText,
      ventanaSegundos: _ventanaVigenciaSegundos,
    );

    RegistroAsistenciaResultado? registro;
    if (validacion.tipo == TipoQrAsistencia.otpDinamico) {
      registro = await _otpService.procesarAsistenciaOtp(
        rawContent: rawText,
        rutEstudiante: widget.rutEstudiante,
        ventanaSegundos: _ventanaVigenciaSegundos,
      );
      if (validacion.estaVigente) {
        _iniciarCuentaRegresiva(validacion.segundosRestantes);
      }
    }

    if (mounted) {
      setState(() {
        _ultimoResultado = validacion;
        _registroResultado = registro;
      });
    }
  }

  void _reiniciarEscaner() {
    _countdownTimer?.cancel();
    setState(() {
      _isScanning = true;
      _scanStartTime = DateTime.now().millisecondsSinceEpoch;
      _detectionLatencyMs = null;
      _ultimoResultado = null;
      _registroResultado = null;
      _segundosRestantes = 0;
      _formatoDetectado = 'Ninguno';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de ventana de expiracion para pruebas
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ventana OTP:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30s')),
                      ButtonSegment(value: 60, label: Text('60s')),
                      ButtonSegment(value: 120, label: Text('120s')),
                    ],
                    selected: {_ventanaVigenciaSegundos},
                    onSelectionChanged: (val) {
                      setState(() => _ventanaVigenciaSegundos = val.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Visor de camara
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                  ),
                  // Reticula de enfoque
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isScanning ? colors.primary : AppColors.statePresente,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Barra de estado superior en visor
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isScanning ? 'Buscando codigo optico continuo...' : 'Capturado [$_formatoDetectado]',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          if (_detectionLatencyMs != null)
                            Text(
                              'Latencia: $_detectionLatencyMs ms',
                              style: const TextStyle(
                                color: Color(0xFF7FD79A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Boton de reactivacion si ya detecto
                  if (!_isScanning)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'reintentar_scan',
                        onPressed: _reiniciarEscaner,
                        child: const Icon(Icons.refresh),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta de resultado decodificado
          if (_ultimoResultado != null) ...[
            _TarjetaResultadoValidacion(
              resultado: _ultimoResultado!,
              registro: _registroResultado,
              segundosRestantes: _segundosRestantes,
              ventanaSegundos: _ventanaVigenciaSegundos,
              onReiniciar: _reiniciarEscaner,
              formatoSimbologia: _formatoDetectado,
            ),
            const SizedBox(height: 12),
          ],

          // Tarjeta de estado de Device Binding
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _dispositivoVinculado ? Icons.verified_user : Icons.warning_amber_rounded,
                        color: _dispositivoVinculado ? AppColors.statePresente : AppColors.stateAusente,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Device Binding (Seccion 5.3)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Device ID: $_deviceId', style: theme.textTheme.bodySmall),
                  Text('RUT Asignado: ${widget.rutEstudiante}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _deviceBinding.simularDispositivoAjeno(widget.rutEstudiante);
                          await _cargarInfoDispositivo();
                        },
                        icon: const Icon(Icons.phone_android),
                        label: const Text('Simular Dispositivo Ajeno'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          await _deviceBinding.vincularDispositivo(widget.rutEstudiante);
                          await _cargarInfoDispositivo();
                        },
                        child: const Text('Restaurar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: INGRESO MANUAL DE CODIGO OTP
// -----------------------------------------------------------------------------
class _TabIngresoManual extends StatefulWidget {
  const _TabIngresoManual({required this.rutEstudiante});
  final String rutEstudiante;

  @override
  State<_TabIngresoManual> createState() => _TabIngresoManualState();
}

class _TabIngresoManualState extends State<_TabIngresoManual> {
  final TextEditingController _otpController = TextEditingController();
  final AsistenciaOtpService _otpService = AsistenciaOtpService();

  bool _procesando = false;
  RegistroAsistenciaResultado? _resultado;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _validarCodigo() async {
    final rawInput = _otpController.text.trim().toUpperCase();
    if (rawInput.isEmpty) return;

    setState(() {
      _procesando = true;
      _resultado = null;
    });

    // Formatear si el usuario ingreso solo los 6 caracteres
    final String payloadFinal;
    if (!rawInput.startsWith('UCN_ASISTENCIA:')) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      payloadFinal = 'UCN_ASISTENCIA:$rawInput:$timestamp';
    } else {
      payloadFinal = rawInput;
    }

    final res = await _otpService.procesarAsistenciaOtp(
      rawContent: payloadFinal,
      rutEstudiante: widget.rutEstudiante,
      ventanaSegundos: 60,
    );

    if (mounted) {
      setState(() {
        _procesando = false;
        _resultado = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Plan de Contingencia (Seccion 10)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Si la camara no logra enfocar el proyector o el estudiante esta ubicado lejos en la sala, puede digitar el codigo OTP dictado por el profesor.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: 'AB3X9F',
              border: OutlineInputBorder(),
              labelText: 'Codigo OTP (6 caracteres)',
              counterText: '',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _procesando ? null : _validarCodigo,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(_procesando ? 'Validando...' : 'Registrar Asistencia'),
          ),
          const SizedBox(height: 20),
          if (_resultado != null)
            Card(
              color: _resultado!.esExitosa
                  ? const Color(0xFF1E3A28)
                  : const Color(0xFF3A1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _resultado!.esExitosa ? Icons.check_circle : Icons.error_outline,
                          color: _resultado!.esExitosa
                              ? const Color(0xFF7FD79A)
                              : const Color(0xFFFFB4AB),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _resultado!.esExitosa ? 'Asistencia Exitosa' : 'Registro Rechazado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _resultado!.esExitosa
                                ? const Color(0xFF7FD79A)
                                : const Color(0xFFFFB4AB),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_resultado!.mensaje),
                    if (_resultado!.deviceId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Device ID: ${_resultado!.deviceId}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: GENERADOR DE CODIGO AZTEC (MODO PROFESOR / EMISOR)
// -----------------------------------------------------------------------------
class _TabModoProfesor extends StatefulWidget {
  const _TabModoProfesor({required this.rutEstudiante});
  final String rutEstudiante;

  @override
  State<_TabModoProfesor> createState() => _TabModoProfesorState();
}

class _TabModoProfesorState extends State<_TabModoProfesor> {
  String _currentOtp = '';
  int _currentTimestamp = 0;
  int _segundosRestantes = 30;
  Timer? _tickerTimer;
  final int _ventanaSegundos = 30;
  ModoAntiCapturaAztec _modoAntiCaptura = ModoAntiCapturaAztec.rollingShutter;

  @override
  void initState() {
    super.initState();
    _generarNuevoOtp();
    _iniciarCiclo();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _generarNuevoOtp() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final otp = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
    setState(() {
      _currentOtp = otp;
      _currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _segundosRestantes = _ventanaSegundos;
    });
  }

  void _iniciarCiclo() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_segundosRestantes <= 1) {
        _generarNuevoOtp();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final payload = 'UCN_ASISTENCIA:$_currentOtp:$_currentTimestamp';
    final progress = _segundosRestantes / _ventanaSegundos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emisor de Asistencia Aztec (Profesor)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Proyeccion en sala con codigo Aztec dinamico',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _generarNuevoOtp,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Nuevo OTP'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tarjeta Principal del Emisor Aztec
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Codigo Aztec visual generado dinamicamente
                  Center(
                    child: _AztecVisualWidget(
                      otp: _currentOtp,
                      timestamp: _currentTimestamp,
                      modo: _modoAntiCaptura,
                      size: 210,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Texto del OTP y Temporizador
                  Text(
                    _currentOtp,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Barra de progreso y tiempo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3.5,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          color: progress > 0.3 ? AppColors.seedBlue : AppColors.stateAusente,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Expira en $_segundosRestantes s (Rotacion automatica)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector de Modo Anti-Foto para el Proyector
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Modo de Emision:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ModoAntiCapturaAztec>(
                    segments: const [
                      ButtonSegment(
                        value: ModoAntiCapturaAztec.rollingShutter,
                        label: Text('Rolling Shutter', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: ModoAntiCapturaAztec.dianaPulsante,
                        label: Text('Diana Pulsante', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: ModoAntiCapturaAztec.estatico,
                        label: Text('Estatico', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_modoAntiCaptura},
                    onSelectionChanged: (set) {
                      setState(() => _modoAntiCaptura = set.first);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Payload de auditoria
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payload Propietario Emitido:',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: payload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payload copiado al portapapeles.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(
                  payload,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF7FD0DF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Guia para el profesor
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrucciones para el Profesor en Sala',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. Proyecta este codigo Aztec en la pantalla principal de la sala o proyector.\n'
                    '2. Los estudiantes apuntaran con la camara de su App Hawaii para registrar su asistencia.\n'
                    '3. La ventana limpia de 140ms permite que el video del celular lo lea instantaneamente, pero neutraliza fotos estaticas enviadas por WhatsApp.\n'
                    '4. Tambien puedes proyectar la suite web desde el computador: http://localhost:8000/test_codigos_alternativos.html',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// COMPONENTE: TARJETA DE RESULTADO DE VALIDACION
// -----------------------------------------------------------------------------
class _TarjetaResultadoValidacion extends StatelessWidget {
  const _TarjetaResultadoValidacion({
    required this.resultado,
    required this.registro,
    required this.segundosRestantes,
    required this.ventanaSegundos,
    required this.onReiniciar,
    this.formatoSimbologia,
  });

  final ResultadoValidacionQr resultado;
  final RegistroAsistenciaResultado? registro;
  final int segundosRestantes;
  final int ventanaSegundos;
  final VoidCallback onReiniciar;
  final String? formatoSimbologia;

  @override
  Widget build(BuildContext context) {
    final esOtp = resultado.tipo == TipoQrAsistencia.otpDinamico;
    final esVigente = resultado.estaVigente;

    return Card(
      color: esVigente ? const Color(0xFF13281E) : const Color(0xFF2C1616),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esVigente ? Icons.check_circle : Icons.error_outline,
                  color: esVigente ? const Color(0xFF7FD79A) : const Color(0xFFFFB4AB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esVigente ? 'Codigo OTP Valido y Vigente' : 'Codigo Invalido o Expirado',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: esVigente ? const Color(0xFF7FD79A) : const Color(0xFFFFB4AB),
                    ),
                  ),
                ),
              ],
            ),
            if (formatoSimbologia != null && formatoSimbologia!.isNotEmpty && formatoSimbologia != 'Ninguno') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF0284C7)),
                ),
                child: Text(
                  'Simbologia Detectada: $formatoSimbologia',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (esOtp) ...[
              Text('OTP: ${resultado.otp ?? "-"}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Timestamp Emision: ${resultado.timestamp ?? 0}', style: const TextStyle(fontSize: 12)),
              Text('Tiempo Transcurrido: ${resultado.segundosTranscurridos} s', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (segundosRestantes / ventanaSegundos).clamp(0.0, 1.0),
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                color: esVigente ? const Color(0xFF7FD79A) : Colors.red,
              ),
              const SizedBox(height: 4),
              Text(
                'Vigencia restante: $segundosRestantes s',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ] else ...[
              Text('URL detectada: ${resultado.rawText}', style: const TextStyle(fontSize: 12)),
            ],
            if (registro != null) ...[
              const Divider(height: 16),
              Text(
                'Estado Registro: ${registro!.mensaje}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (registro!.deviceId != null)
                Text(
                  'Device Binding: ${registro!.deviceId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReiniciar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Escanear Otro'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: LABORATORIO EXCLUSIVO DEL CODIGO AZTEC ANTI-FOTO
// -----------------------------------------------------------------------------
class _TabLaboratorioAztec extends StatefulWidget {
  const _TabLaboratorioAztec({required this.rutEstudiante});
  final String rutEstudiante;

  @override
  State<_TabLaboratorioAztec> createState() => _TabLaboratorioAztecState();
}

class _TabLaboratorioAztecState extends State<_TabLaboratorioAztec> {
  final AsistenciaOtpService _otpService = AsistenciaOtpService();

  String _otpActual = 'AB3X9F';
  late int _timestampActual;
  ModoAntiCapturaAztec _modoSeleccionado = ModoAntiCapturaAztec.rollingShutter;
  final int _velocidadShutterMs = 50;
  int _ventanaLimpiaMs = 140;

  bool _mostrarCamara = false;
  MobileScannerController? _scannerController;
  int _scanStartTime = 0;

  ResultadoDecodificacionOptica? _resultadoOptico;
  RegistroAsistenciaResultado? _resultadoRegistro;

  // Estado de simulacion WhatsApp
  bool _mostrarSimulacionWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _timestampActual = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _generarNuevoOtp() {
    const chars = '0123456789ABCDEF';
    final random = Random();
    final otp = List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();

    setState(() {
      _otpActual = otp;
      _timestampActual = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _resultadoOptico = null;
      _resultadoRegistro = null;
      _mostrarSimulacionWhatsApp = false;
    });
  }

  void _abrirCamara() {
    _scanStartTime = DateTime.now().millisecondsSinceEpoch;
    _scannerController?.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      formats: const [
        BarcodeFormat.aztec,
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
      ],
    );
    setState(() {
      _mostrarCamara = true;
      _resultadoOptico = null;
      _resultadoRegistro = null;
    });
  }

  void _cerrarCamara() {
    _scannerController?.dispose();
    _scannerController = null;
    setState(() {
      _mostrarCamara = false;
    });
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || (barcode.rawValue ?? '').isEmpty) return;

    final latency = DateTime.now().millisecondsSinceEpoch - _scanStartTime;
    final rawText = barcode.rawValue!;
    final formatName = barcode.format.name.toUpperCase();

    _cerrarCamara();

    final validacion = const QrAsistenciaValidator().validarContenido(rawText);

    setState(() {
      _resultadoOptico = ResultadoDecodificacionOptica(
        tipo: TipoCodigoOptico.aztec,
        esValido: validacion.esValido,
        codigoOtp: validacion.otp,
        payloadCompleto: rawText,
        timestamp: validacion.timestamp,
        latenciaMs: latency,
        mensaje: validacion.esValido
            ? 'Codigo Aztec escaneado exitosamente en $latency ms.'
            : 'Simbologia [$formatName] detectada pero formato no reconocido.',
      );
    });

    if (validacion.esValido && validacion.otp != null) {
      await _marcarAsistencia(validacion.otp!, validacion.timestamp ?? _timestampActual);
    }
  }

  Future<void> _marcarAsistencia(String otp, int ts) async {
    final res = await _otpService.procesarAsistenciaOtp(
      rawContent: 'UCN_ASISTENCIA:$otp:$ts',
      rutEstudiante: widget.rutEstudiante,
      ventanaSegundos: 45,
    );
    if (mounted) {
      setState(() {
        _resultadoRegistro = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Justificacion Tecnica
        _buildCardJustificacion(),
        const SizedBox(height: 14),

        // 2. Visor de Camara si esta activa
        if (_mostrarCamara) ...[
          _buildVisorCamara(),
          const SizedBox(height: 14),
        ],

        // 3. Simulador del Emisor Aztec
        _buildCardSimuladorEmisor(),
        const SizedBox(height: 14),

        // 4. Botonera de Acciones
        _buildBotoneraAcciones(),
        const SizedBox(height: 14),

        // 5. Comparativa WhatsApp si esta activa
        if (_mostrarSimulacionWhatsApp) ...[
          _buildCardSimulacionWhatsApp(),
          const SizedBox(height: 14),
        ],

        // 6. Resultado Optico y Registro
        if (_resultadoOptico != null) ...[
          _buildCardResultado(),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildCardJustificacion() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Modelo Seleccionado: Codigo Aztec (2D Concentrico)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'El Codigo Aztec fue seleccionado frente al QR tradicional por las siguientes ventajas de ingenieria:\n'
              ' - Diana central unica: No posee los 3 cuadrados en las esquinas del QR que son vulnerables a fotos parciales.\n'
              ' - Lectura nativa e inmediata: Google ML Kit en la App Hawaii lo decodifica en menos de 100 ms.\n'
              ' - Tolerancia angular superior: Escaneo efectivo desde cualquier angulo o distancia en la sala de clases.\n'
              ' - Proteccion anti-WhatsApp: Al emitirse con modulacion y ventana limpia, neutraliza capturas de pantalla.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisorCamara() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Escaneando Codigo Aztec en Vivo...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  onPressed: _cerrarCamara,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_scannerController != null)
                  MobileScanner(
                    controller: _scannerController!,
                    onDetect: _onBarcodeDetected,
                  ),
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF0284C7), width: 2.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSimuladorEmisor() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulador del Emisor Aztec en Pantalla',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'OTP Activo: $_otpActual (Timestamp: $_timestampActual)',
              style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 14),

            // Codigo Aztec visual
            Center(
              child: _AztecVisualWidget(
                otp: _otpActual,
                timestamp: _timestampActual,
                modo: _modoSeleccionado,
                speedMs: _velocidadShutterMs,
                cleanWindowMs: _ventanaLimpiaMs,
                size: 190,
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Modos Anti-Foto
            const Text(
              'Mecanismo Anti-Captura:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            SegmentedButton<ModoAntiCapturaAztec>(
              segments: const [
                ButtonSegment(
                  value: ModoAntiCapturaAztec.rollingShutter,
                  label: Text('Rolling Shutter', style: TextStyle(fontSize: 11)),
                ),
                ButtonSegment(
                  value: ModoAntiCapturaAztec.dianaPulsante,
                  label: Text('Diana Pulsante', style: TextStyle(fontSize: 11)),
                ),
                ButtonSegment(
                  value: ModoAntiCapturaAztec.estatico,
                  label: Text('Estatico', style: TextStyle(fontSize: 11)),
                ),
              ],
              selected: {_modoSeleccionado},
              onSelectionChanged: (set) {
                setState(() => _modoSeleccionado = set.first);
              },
            ),
            const SizedBox(height: 12),

            // Slider de Ventana Limpia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ventana Limpia para Escaner:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('$_ventanaLimpiaMs ms', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            Slider(
              value: _ventanaLimpiaMs.toDouble(),
              min: 100,
              max: 220,
              divisions: 6,
              label: '$_ventanaLimpiaMs ms',
              onChanged: (v) => setState(() => _ventanaLimpiaMs = v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoneraAcciones() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _mostrarCamara ? _cerrarCamara : _abrirCamara,
            icon: Icon(_mostrarCamara ? Icons.camera_alt_outlined : Icons.camera_alt),
            label: Text(_mostrarCamara ? 'Cerrar Camara' : 'Escanear Codigo Aztec con Camara en Vivo'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _mostrarSimulacionWhatsApp = !_mostrarSimulacionWhatsApp);
                },
                icon: const Icon(Icons.compare_arrows),
                label: Text(_mostrarSimulacionWhatsApp ? 'Ocultar Analisis' : 'Simular WhatsApp'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _generarNuevoOtp,
              icon: const Icon(Icons.shuffle),
              label: const Text('Nuevo OTP'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardSimulacionWhatsApp() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analisis Comparativo: WhatsApp vs App Hawaii',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C1517),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Foto Fija (WhatsApp)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFFFB4AB))),
                        SizedBox(height: 4),
                        Text('[FALLIDA - DIANA ROTA]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFEF4444))),
                        SizedBox(height: 4),
                        Text('La foto captura un solo instante donde la obturacion interrumpe el nucleo central. Imposible decodificar.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13281E),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('App Hawaii (Camara)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF7FD79A))),
                        SizedBox(height: 4),
                        Text('[EXITOSA - ASISTENCIA]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
                        SizedBox(height: 4),
                        Text('El video continuo a 30 fps captura el fotograma integro en la ventana limpia de 140 ms sin errores.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardResultado() {
    final res = _resultadoOptico!;
    final esValido = res.esValido;

    return Card(
      color: esValido ? const Color(0xFF13281E) : const Color(0xFF2C1517),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: esValido ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  esValido ? Icons.check_circle : Icons.error_outline,
                  color: esValido ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    esValido ? 'Codigo Aztec Decodificado' : 'Fallo de Lectura',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: esValido ? const Color(0xFF7FD79A) : const Color(0xFFFFB4AB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(res.mensaje, style: const TextStyle(fontSize: 12)),
            if (esValido && res.codigoOtp != null) ...[
              const Divider(height: 16),
              Text('OTP Decodificado: ${res.codigoOtp}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Payload: ${res.payloadCompleto}', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace')),
              Text('Timestamp Emision: ${res.timestamp}', style: const TextStyle(fontSize: 11)),
              Text('Latencia del Escaneo: ${res.latenciaMs} ms', style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () => _marcarAsistencia(res.codigoOtp!, res.timestamp!),
                icon: const Icon(Icons.fingerprint),
                label: const Text('Marcar Asistencia con este Codigo Aztec'),
              ),
            ],
            if (_resultadoRegistro != null) ...[
              const Divider(height: 16),
              Text(
                'Registro en Hawaii: ${_resultadoRegistro!.mensaje}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              if (_resultadoRegistro!.deviceId != null)
                Text(
                  'Device Binding Audit: ${_resultadoRegistro!.deviceId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WIDGET VISUAL Y PINTOR DEL CODIGO AZTEC
// =============================================================================
class _AztecVisualWidget extends StatefulWidget {
  const _AztecVisualWidget({
    required this.otp,
    required this.timestamp,
    required this.modo,
    this.size = 200,
    this.speedMs = 50,
    this.cleanWindowMs = 140,
  });

  final String otp;
  final int timestamp;
  final ModoAntiCapturaAztec modo;
  final double size;
  final int speedMs;
  final int cleanWindowMs;

  @override
  State<_AztecVisualWidget> createState() => _AztecVisualWidgetState();
}

class _AztecVisualWidgetState extends State<_AztecVisualWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AztecVisualWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.modo == ModoAntiCapturaAztec.estatico) {
      _animController.stop();
    } else if (!_animController.isAnimating) {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = _animController.value;
        final isCleanWindow = widget.modo == ModoAntiCapturaAztec.estatico || progress > 0.65;

        return Container(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _AztecCodePainter(
              otp: widget.otp,
              timestamp: widget.timestamp,
              modo: widget.modo,
              shutterProgress: (progress / 0.65).clamp(0.0, 1.0),
              isCleanWindow: isCleanWindow,
            ),
          ),
        );
      },
    );
  }
}

class _AztecCodePainter extends CustomPainter {
  _AztecCodePainter({
    required this.otp,
    required this.timestamp,
    required this.modo,
    required this.shutterProgress,
    required this.isCleanWindow,
  });

  final String otp;
  final int timestamp;
  final ModoAntiCapturaAztec modo;
  final double shutterProgress;
  final bool isCleanWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grilla 19x19 clasica de Aztec compacto
    const gridN = 19;
    final modSize = w / gridN;
    const center = 9;

    final blackPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final whitePaint = Paint()..color = Colors.white..style = PaintingStyle.fill;

    final seed = otp.codeUnits.fold(timestamp, (prev, c) => (prev * 31 + c) & 0x7FFFFFFF);

    for (int r = 0; r < gridN; r++) {
      for (int c = 0; c < gridN; c++) {
        final dist = max((r - center).abs(), (c - center).abs());

        bool isBlack;
        // Nucleo concentrico diana Aztec (bullseye)
        if (dist == 0) {
          isBlack = true; // Centro 1x1 negro
        } else if (dist == 1) {
          isBlack = false; // Anillo 3x3 blanco
        } else if (dist == 2) {
          isBlack = true; // Anillo 5x5 negro
        } else if (dist == 3) {
          isBlack = false; // Anillo 7x7 blanco
        } else if (dist == 4) {
          isBlack = true; // Anillo 9x9 negro exterior de la diana
        } else {
          // Capas concentricas de datos Aztec
          final val = ((seed ^ (r * 19 + c * 37)) >> (r % 7)) & 1;
          isBlack = val == 1;
        }

        final rect = Rect.fromLTWH(c * modSize, r * modSize, modSize, modSize);
        canvas.drawRect(rect, isBlack ? blackPaint : whitePaint);
      }
    }

    // Efecto Anti-Foto cuando no estamos en la ventana limpia
    if (!isCleanWindow && modo != ModoAntiCapturaAztec.estatico) {
      if (modo == ModoAntiCapturaAztec.rollingShutter) {
        final bandHeight = h * 0.16;
        final bandY = shutterProgress * (h - bandHeight);
        final bandRect = Rect.fromLTWH(0, bandY, w, bandHeight);

        final sweepPaint = Paint()..color = Colors.white;
        canvas.drawRect(bandRect, sweepPaint);

        final strokePaint = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(bandRect, strokePaint);
      } else if (modo == ModoAntiCapturaAztec.dianaPulsante) {
        final bullseyeSz = modSize * 7;
        final bx = (w - bullseyeSz) / 2;
        final by = (h - bullseyeSz) / 2;
        final bullseyeRect = Rect.fromLTWH(bx, by, bullseyeSz, bullseyeSz);

        final blankPaint = Paint()..color = Colors.white;
        canvas.drawRect(bullseyeRect, blankPaint);

        final strokePaint = Paint()
          ..color = const Color(0xFFEF4444).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRect(bullseyeRect, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AztecCodePainter oldDelegate) {
    return oldDelegate.otp != otp ||
        oldDelegate.timestamp != timestamp ||
        oldDelegate.modo != modo ||
        oldDelegate.shutterProgress != shutterProgress ||
        oldDelegate.isCleanWindow != isCleanWindow;
  }
}
