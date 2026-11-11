/// Resolve um caminho na pasta da página que abriu o QR.
///
/// `index.html?70&2` em `/pwa/` vira `/pwa/imagens/...`, não a raiz do site.
String urlNaPagina(String relativo, {Uri? pagina}) {
  if (relativo.startsWith('http://') || relativo.startsWith('https://')) {
    return relativo;
  }
  final base = pagina ?? Uri.base;
  if (base.scheme != 'http' && base.scheme != 'https') return relativo;
  final destino = relativo.startsWith('/')
      ? base.replace(path: relativo)
      : base.resolve(relativo);
  return Uri(
    scheme: destino.scheme,
    host: destino.host,
    port: destino.hasPort ? destino.port : null,
    path: destino.path,
  ).toString();
}
