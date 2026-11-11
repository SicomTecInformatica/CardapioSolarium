import 'dart:convert';

import 'json_values.dart';

class CartLine {
  final int codigo;
  final String descricao;
  final double quantidade;
  final double valorUnitario;
  final List<String> observacoes;

  CartLine({
    this.codigo = 0,
    this.descricao = '',
    this.quantidade = 0,
    this.valorUnitario = 0,
    List<String> observacoes = const [],
  }) : observacoes = _limitar(observacoes);

  double get total => valorUnitario * quantidade;

  List<String> observacoesParaEnvio() {
    return List<String>.generate(
      5,
      (index) => index < observacoes.length ? observacoes[index] : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'descricao': descricao,
      'quantidade': quantidade,
      'valorUnitario': valorUnitario,
      'observacoes': observacoes,
    };
  }

  factory CartLine.fromJson(dynamic json) {
    final map = asMap(json);
    final raw = map['observacoes'];
    final observacoes = <String>[];
    if (raw is List) {
      for (final item in raw) {
        observacoes.add(asString(item));
      }
    }
    return CartLine(
      codigo: asInt(map['codigo']),
      descricao: asString(map['descricao']),
      quantidade: asDouble(map['quantidade']),
      valorUnitario: asDouble(map['valorUnitario']),
      observacoes: observacoes,
    );
  }

  static List<CartLine> listFromStorage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final lines = <CartLine>[];
      for (final item in decoded) {
        lines.add(CartLine.fromJson(item));
        if (lines.length == 25) break;
      }
      return lines;
    } catch (_) {
      return const [];
    }
  }

  static List<String> _limitar(List<String> observacoes) {
    if (observacoes.length <= 5) return List<String>.unmodifiable(observacoes);
    return List<String>.unmodifiable(observacoes.take(5));
  }
}
