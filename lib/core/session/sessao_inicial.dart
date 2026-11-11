import 'qr_mesa.dart';

class SessaoInicial {
  final int mesa;
  final int local;
  final bool temQuery;
  final DateTime horaEntrada;
  final bool autenticado;
  final bool gravarEntrada;
  final String nomeSocio;
  final int idSocio;

  const SessaoInicial({
    required this.mesa,
    required this.local,
    required this.temQuery,
    required this.horaEntrada,
    required this.autenticado,
    required this.gravarEntrada,
    this.nomeSocio = '',
    this.idSocio = 0,
  });
}

/// A hora conta da abertura do QR gravada, não do último toque.
/// Sem query, a mesa da visita anterior não volta.
/// Cada carga da página pede a senha de novo, para reler as cores do clube.
SessaoInicial decidirSessaoInicial({
  required QrMesa qr,
  required DateTime agora,
  required int tempoExpira,
  required String titulo,
  String nomeSocio = '',
  int idSocio = 0,
  int? mesaGravada,
  int? localGravado,
  DateTime? horaGravada,
}) {
  final util = qr.temQuery && qr.mesa != 0 && qr.local != 0;
  if (!util) {
    return SessaoInicial(
      mesa: qr.temQuery ? qr.mesa : 0,
      local: qr.temQuery ? qr.local : 0,
      temQuery: qr.temQuery,
      horaEntrada: agora,
      autenticado: false,
      gravarEntrada: false,
    );
  }

  final mesmaVisita =
      mesaGravada == qr.mesa && localGravado == qr.local && horaGravada != null;
  final hora = mesmaVisita ? horaGravada : agora;
  return SessaoInicial(
    mesa: qr.mesa,
    local: qr.local,
    temQuery: true,
    horaEntrada: hora,
    autenticado: false,
    gravarEntrada: !mesmaVisita,
  );
}
