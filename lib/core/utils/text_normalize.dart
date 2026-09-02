String normalizarBusqueda(String texto) {
  var resultado = texto.toLowerCase();
  const conTilde = 'áéíóúüñ';
  const sinTilde = 'aeiouun';
  for (var i = 0; i < conTilde.length; i++) {
    resultado = resultado.replaceAll(conTilde[i], sinTilde[i]);
  }
  return resultado;
}

/// Extrae el nombre limpio y corto de un curso eliminando códigos entre paréntesis.
/// Ej: "Electivo Desarrollo Basado en Plataforma (ECIN-00003) {C1}" -> "Electivo Desarrollo Basado en Plataforma"
String nombreCursoCorto(String nombreCompleto) {
  final match = RegExp(r'^(.+?)\s*\(').firstMatch(nombreCompleto);
  return match?.group(1)?.trim() ?? nombreCompleto;
}