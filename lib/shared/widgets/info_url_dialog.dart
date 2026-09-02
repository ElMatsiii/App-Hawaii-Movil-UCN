import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Diálogo informativo reutilizable con título, descripción y botón de acción
/// para abrir un enlace externo (formularios, instructivos, etc.).
class InfoUrlDialog extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String url;
  final String labelBoton;

  const InfoUrlDialog({
    required this.titulo,
    required this.descripcion,
    required this.url,
    required this.labelBoton,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(descripcion),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: Text(labelBoton),
                onPressed: () {
                  Navigator.of(context).pop();
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
