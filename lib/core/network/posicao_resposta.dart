String normalizarCorpoPedido(String body) {
  return body
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll('\r', '')
      .replaceAll('\n', '')
      .trim();
}

int? parsePosicaoOk(String body) {
  final text = normalizarCorpoPedido(body);
  if (!text.startsWith('OK|')) return null;
  final parts = text.split('|');
  if (parts.length < 2) return null;
  const prefix = 'POSICAO=';
  final piece = parts[1].trim();
  if (!piece.startsWith(prefix)) return null;
  return int.tryParse(piece.substring(prefix.length).trim());
}
