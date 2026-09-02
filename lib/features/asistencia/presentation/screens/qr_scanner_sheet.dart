part of 'asistencia_screen.dart';

class _QrScannerSheet extends StatefulWidget {
  const _QrScannerSheet();

  @override
  State<_QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<_QrScannerSheet>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  bool _detectado = false;
  double _zoomScale = 0;

  /// Validacion de las URLs de QR (dominio + ruta). Logica pura y testeada en
  /// test/unit/qr_asistencia_validator_test.dart.
  static const _validator = QrAsistenciaValidator();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_syncZoomScale);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (!_detectado) _controller.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller
      ..removeListener(_syncZoomScale)
      ..dispose();
    super.dispose();
  }

  void _syncZoomScale() {
    if (!mounted || !_controller.value.isInitialized) return;
    final zoomScale = _controller.value.zoomScale.clamp(0.0, 1.0);
    if ((zoomScale - _zoomScale).abs() < 0.01) return;
    setState(() => _zoomScale = zoomScale);
  }

  Future<void> _setZoomScale(double value) async {
    final nextValue = value.clamp(0.0, 1.0);
    setState(() => _zoomScale = nextValue);
    await _controller.setZoomScale(nextValue);
  }

  void _previewZoomScale(double value) {
    setState(() => _zoomScale = value.clamp(0.0, 1.0));
  }

  Future<void> _resetZoom() async {
    setState(() => _zoomScale = 0);
    await _controller.resetZoomScale();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_detectado) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty) return;
    _detectado = true;
    await _controller.stop();
    if (!mounted) return;

    // Capturamos el messenger antes del pop para no usar el context tras los
    // await (evita el lint use_build_context_synchronously y que el aviso se
    // pierda cuando el bottom sheet ya se cerro).
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    final uri = Uri.tryParse(raw);
    if (uri == null || !_validator.esValido(uri)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('QR no reconocido o endpoint no autorizado'),
        ),
      );
      return;
    }

    try {
      final abierto = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!abierto) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el enlace de asistencia'),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo abrir el enlace: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Escanea el codigo QR',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _ScannerZoomControls(
                      zoomScale: _zoomScale,
                      onChanged: _previewZoomScale,
                      onChangeEnd: _setZoomScale,
                      onZoomOut: () => _setZoomScale(_zoomScale - 0.15),
                      onZoomIn: () => _setZoomScale(_zoomScale + 0.15),
                      onReset: _resetZoom,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Apunta la camara al QR del profesor para registrar tu asistencia',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerZoomControls extends StatelessWidget {
  const _ScannerZoomControls({
    required this.zoomScale,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });

  final double zoomScale;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final percent = (zoomScale * 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Alejar',
                onPressed: zoomScale <= 0 ? null : onZoomOut,
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Slider(
                  value: zoomScale,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
              IconButton(
                tooltip: 'Acercar',
                onPressed: zoomScale >= 1 ? null : onZoomIn,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: zoomScale <= 0 ? null : onReset,
                child: Text(
                  '$percent%',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
