import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HorarioSearchBar extends ConsumerStatefulWidget {
  final ValueChanged<String> onChanged;

  /// Controller externo opcional. Si se provee, este widget NO lo dispone.
  final TextEditingController? controller;

  const HorarioSearchBar({
    required this.onChanged,
    this.controller,
    super.key,
  });

  @override
  ConsumerState<HorarioSearchBar> createState() => _HorarioSearchBarState();
}

class _HorarioSearchBarState extends ConsumerState<HorarioSearchBar> {
  late final TextEditingController _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }
    // Refrescar el ícono cuando el controller cambia externamente
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    // Solo llamar setState si el widget sigue montado
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    // Solo disposar si somos dueños del controller
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;

    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: 'Buscar ramo, profesor, sala...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
        isDense: true,
      ),
      onChanged: (value) {
        widget.onChanged(value);
        // setState ya es llamado por el listener del controller
      },
    );
  }
}