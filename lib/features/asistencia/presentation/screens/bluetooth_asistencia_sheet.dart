part of 'asistencia_screen.dart';

class _BluetoothAsistenciaSheet extends ConsumerStatefulWidget {
  final List<CursoUsuarioEntity> cursosDisponibles;
  final String rutEstudiante;
  final int semestreId;

  const _BluetoothAsistenciaSheet({
    required this.cursosDisponibles,
    required this.rutEstudiante,
    required this.semestreId,
  });

  @override
  ConsumerState<_BluetoothAsistenciaSheet> createState() =>
      _BluetoothAsistenciaSheetState();
}

class _BluetoothAsistenciaSheetState
    extends ConsumerState<_BluetoothAsistenciaSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Iniciar escaneo automáticamente al abrir el sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bluetoothAsistenciaProvider.notifier).iniciarEscaneo(
            cursosDisponibles: widget.cursosDisponibles,
          );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bluetoothAsistenciaProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bluetooth_searching,
                  color: colors.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asistencia por Bluetooth',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Detección automática de baliza de clase',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Body según estado
          Expanded(
            child: SingleChildScrollView(
              child: switch (state.status) {
                BluetoothAsistenciaStatus.idle ||
                BluetoothAsistenciaStatus.checkingPermissions =>
                  _buildLoadingState(theme, 'Verificando Bluetooth...'),
                BluetoothAsistenciaStatus.scanning =>
                  _buildScanningState(theme, colors),
                BluetoothAsistenciaStatus.bluetoothOff =>
                  _buildBluetoothOffState(theme, colors),
                BluetoothAsistenciaStatus.permissionsDenied =>
                  _buildPermissionsDeniedState(theme, colors),
                BluetoothAsistenciaStatus.beaconFound =>
                  _buildBeaconDetectedState(state, theme, colors),
                BluetoothAsistenciaStatus.registering =>
                  _buildLoadingState(theme, 'Registrando asistencia...'),
                BluetoothAsistenciaStatus.success =>
                  _buildSuccessState(state, theme, colors),
                BluetoothAsistenciaStatus.error =>
                  _buildErrorState(state, theme, colors),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(texto, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningState(ThemeData theme, ColorScheme colors) {
    return Column(
      children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ondas de radar
                for (int i = 1; i <= 3; i++)
                  Opacity(
                    opacity: (1 - (_pulseController.value + (i * 0.25)) % 1)
                        .clamp(0.0, 1.0) *
                        0.4,
                    child: Container(
                      width: 80 + (i * 45 * _pulseController.value),
                      height: 80 + (i * 45 * _pulseController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_audio,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          'Buscando la señal de tu profesor...',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Permanece en la sala de clases. La baliza se detectará en unos segundos.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),

        // Opción para simular en caso de desarrollo / pruebas
        _buildSimulatorTile(theme, colors),
      ],
    );
  }

  Widget _buildBeaconDetectedState(
    BluetoothAsistenciaState state,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final payload = state.payload!;
    final curso = state.cursoCoincidente;
    final prox = payload.nivelProximidad;
    final esValido = payload.esAceptableParaAsistencia;

    final colorProximidad = switch (prox) {
      NivelProximidad.enSala => Colors.green,
      NivelProximidad.cercano => Colors.teal,
      NivelProximidad.alLimite => Colors.orange,
      NivelProximidad.fueraDeRango => Colors.red,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.esModoSimulado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                const Icon(Icons.science, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Modo de Prueba / Simulación Activo',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                  ),
                ),
              ],
            ),
          ),

        // Tarjeta de la clase detectada
        Card(
          elevation: 0,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        curso?.codigo ?? 'CURSO #${payload.cursoId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 16,
                          color: colorProximidad,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${payload.rssi} dBm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorProximidad,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  curso?.nombre ?? 'Clase UCN ID: ${payload.cursoId}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (payload.bloque != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bloque: ${payload.bloque}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Indicador de proximidad
                Row(
                  children: [
                    Icon(
                      esValido ? Icons.check_circle : Icons.warning_amber,
                      color: colorProximidad,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prox.etiqueta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorProximidad,
                            ),
                          ),
                          Text(
                            'Distancia estimada: ~${payload.distanciaAproximadaMetros} m',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        FilledButton.icon(
          onPressed: esValido
              ? () {
                  ref.read(bluetoothAsistenciaProvider.notifier).confirmarAsistencia(
                        rutEstudiante: widget.rutEstudiante,
                        semestreId: widget.semestreId,
                      );
                }
              : null,
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Confirmar Asistencia en esta Clase'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(bluetoothAsistenciaProvider.notifier).iniciarEscaneo(
                  cursosDisponibles: widget.cursosDisponibles,
                );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Volver a buscar'),
        ),
      ],
    );
  }

  Widget _buildSuccessState(
    BluetoothAsistenciaState state,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final res = state.resultado;
    final ahora = res?.fechaRegistro ?? DateTime.now();
    final horaTexto = DateFormat('HH:mm').format(ahora);

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.shade400, width: 2),
          ),
          child: const Icon(
            Icons.check,
            color: Colors.green,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '¡Asistencia Registrada!',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          res?.mensaje ?? 'Tu asistencia ha sido confirmada correctamente.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow('Hora de registro', horaTexto),
              const SizedBox(height: 6),
              _buildInfoRow(
                'Método de verificación',
                'Bluetooth BLE (Baliza)',
              ),
              const SizedBox(height: 6),
              _buildInfoRow('Potencia recibida', '${res?.rssiRegistrado ?? 0} dBm'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Invalidar provider para actualizar la lista de asistencia
            ref.invalidate(asistenciaEstudianteProvider);
          },
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          valor,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBluetoothOffState(ThemeData theme, ColorScheme colors) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.bluetooth_disabled, size: 64, color: colors.error),
        const SizedBox(height: 16),
        Text(
          'Bluetooth Desactivado',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Por favor enciende el Bluetooth en los ajustes de tu teléfono para detectar la señal del aula.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () {
            ref.read(bluetoothAsistenciaProvider.notifier).iniciarEscaneo(
                  cursosDisponibles: widget.cursosDisponibles,
                );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Ya lo encendí, reintentar'),
        ),
      ],
    );
  }

  Widget _buildPermissionsDeniedState(ThemeData theme, ColorScheme colors) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.security, size: 64, color: colors.error),
        const SizedBox(height: 16),
        Text(
          'Permisos Requeridos',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La app necesita permiso de Bluetooth y Ubicación para detectar las balizas de asistencia en el campus.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => openAppSettings(),
          child: const Text('Abrir Ajustes de la App'),
        ),
      ],
    );
  }

  Widget _buildErrorState(
    BluetoothAsistenciaState state,
    ThemeData theme,
    ColorScheme colors,
  ) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.error_outline, size: 64, color: colors.error),
        const SizedBox(height: 16),
        Text(
          'No se pudo registrar asistencia',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.mensajeError ?? 'Ocurrió un inconveniente al buscar la clase.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            ref.read(bluetoothAsistenciaProvider.notifier).iniciarEscaneo(
                  cursosDisponibles: widget.cursosDisponibles,
                );
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar escaneo'),
        ),
        const SizedBox(height: 12),
        _buildSimulatorTile(theme, colors),
      ],
    );
  }

  Widget _buildSimulatorTile(ThemeData theme, ColorScheme colors) {
    if (widget.cursosDisponibles.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        title: Text(
          'Modo de Prueba / Simulación de Baliza',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Permite simular la llegada de señal para pruebas rápidas sin baliza física',
          style: TextStyle(fontSize: 12),
        ),
        leading: Icon(Icons.developer_mode, color: colors.primary),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona una de tus asignaturas para simular la señal del profesor:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...widget.cursosDisponibles.map(
                  (curso) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.bluetooth, size: 20),
                    title: Text(curso.nombre),
                    subtitle: Text('NRC/ID: ${curso.id} • ${curso.codigo}'),
                    trailing: FilledButton.tonal(
                      child: const Text('Simular'),
                      onPressed: () {
                        ref
                            .read(bluetoothAsistenciaProvider.notifier)
                            .simularDeteccion(curso: curso);
                      },
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
}
