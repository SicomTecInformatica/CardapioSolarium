class QrMesa {
  final int mesa;
  final int local;
  final bool temQuery;

  const QrMesa({
    required this.mesa,
    required this.local,
    required this.temQuery,
  });
}

QrMesa parseQrMesa(String url) {
  final mark = url.indexOf('?');
  if (mark < 0) {
    return const QrMesa(mesa: 0, local: 0, temQuery: false);
  }
  var query = url.substring(mark + 1);
  final hash = query.indexOf('#');
  if (hash >= 0) query = query.substring(0, hash);
  final parts = query.split('&');
  return QrMesa(
    mesa: _numero(parts, 0),
    local: _numero(parts, 1),
    temQuery: true,
  );
}

int _numero(List<String> parts, int index) {
  if (index >= parts.length) return 0;
  return int.tryParse(parts[index].trim()) ?? 0;
}
