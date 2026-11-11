import 'json_values.dart';

class Observacao {
  final String obsDescricao;

  const Observacao({this.obsDescricao = ''});

  factory Observacao.fromJson(dynamic json) {
    final map = asMap(json);
    return Observacao(obsDescricao: asString(map['obs_descricao']));
  }
}
