import 'json_values.dart';

class Produto {
  final int codigo;
  final String descricao;
  final double preco;
  final bool contemGluten;
  final bool contemLactose;
  final bool vegano;
  final String kcal;
  final String ingredientes;

  const Produto({
    this.codigo = 0,
    this.descricao = '',
    this.preco = 0,
    this.contemGluten = false,
    this.contemLactose = false,
    this.vegano = false,
    this.kcal = '',
    this.ingredientes = '',
  });

  factory Produto.fromJson(dynamic json) {
    final map = asMap(json);
    return Produto(
      codigo: asInt(map['codigo']),
      descricao: asString(map['descricao']),
      preco: asDouble(map['preco']),
      contemGluten: asBool(map['contemGluten']),
      contemLactose: asBool(map['contemLactose']),
      vegano: asBool(map['vegano']),
      kcal: asString(map['kcal']),
      ingredientes: asString(map['ingredientes']),
    );
  }
}
