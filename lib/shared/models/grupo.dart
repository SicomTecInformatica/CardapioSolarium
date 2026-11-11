import 'json_values.dart';

class Grupo {
  final int codigoGrupo;
  final String descricaoGrupo;

  const Grupo({
    this.codigoGrupo = 0,
    this.descricaoGrupo = '',
  });

  factory Grupo.fromJson(dynamic json) {
    final map = asMap(json);
    return Grupo(
      codigoGrupo: asInt(map['codigoGrupo']),
      descricaoGrupo: asString(map['descricaoGrupo']),
    );
  }
}
