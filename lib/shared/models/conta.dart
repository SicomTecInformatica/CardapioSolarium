import 'json_values.dart';

class Conta {
  final String abertura;
  final String atendente;
  final double valorConsumido;
  final String socio;

  const Conta({
    this.abertura = '',
    this.atendente = '',
    this.valorConsumido = 0,
    this.socio = '',
  });

  factory Conta.fromJson(dynamic json) {
    final map = asMap(json);
    return Conta(
      abertura: asString(map['abertura']),
      atendente: asString(map['atendente']),
      valorConsumido: asDouble(map['valorConsumido']),
      socio: asString(map['socio']),
    );
  }
}

class ContaItem {
  final int produto;
  final String descricao;
  final double quantidade;
  final double valor;

  const ContaItem({
    this.produto = 0,
    this.descricao = '',
    this.quantidade = 0,
    this.valor = 0,
  });

  factory ContaItem.fromJson(dynamic json) {
    final map = asMap(json);
    return ContaItem(
      produto: asInt(map['itm_produto'] ?? map['prd']),
      descricao: asString(map['itm_descricao'] ?? map['desc']),
      quantidade: asDouble(map['itm_quantidade'] ?? map['qtd']),
      valor: asDouble(map['itm_valor'] ?? map['vlr']),
    );
  }
}
