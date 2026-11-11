import 'json_values.dart';

class MesaStatus {
  final String socio;
  final bool fechaConta;
  final int posicao;
  final int mesa;

  const MesaStatus({
    this.socio = '',
    this.fechaConta = false,
    this.posicao = 0,
    this.mesa = 0,
  });

  factory MesaStatus.fromJson(dynamic json) {
    final map = asMap(json);
    return MesaStatus(
      socio: asString(map['socio']),
      fechaConta: asBool(map['fechaConta']),
      posicao: asInt(map['posicao']),
      mesa: asInt(map['mesa']),
    );
  }
}
