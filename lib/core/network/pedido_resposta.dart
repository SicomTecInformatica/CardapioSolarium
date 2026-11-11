import 'dart:convert';

import 'posicao_resposta.dart';

enum EfeitoRespostaPedido { sucesso, esvaziar, manter }

class RespostaPedido {
  final EfeitoRespostaPedido efeito;
  final String texto;
  final int? posicao;

  const RespostaPedido({
    required this.efeito,
    this.texto = '',
    this.posicao,
  });
}

const msgMesaFechada = 'Mesa se encontra fechada.';
const msgMesaOutroSocio = 'Mesa se encontra aberta em outro sócio.';
const msgSocioOutraMesa = 'Socio já esta logado em outra mesa.';
const prefixoChavePrimaria =
    "Erro ao gravar pedido. Violação da restrição PRIMARY KEY 'PK_MESAH'";

RespostaPedido lerRespostaPedido(String corpo, {Object? dados}) {
  if (corpo.trim().isEmpty) {
    return const RespostaPedido(efeito: EfeitoRespostaPedido.sucesso);
  }
  if (normalizarCorpoPedido(corpo).startsWith('OK|')) {
    return RespostaPedido(
      efeito: EfeitoRespostaPedido.sucesso,
      posicao: parsePosicaoOk(corpo),
    );
  }

  final texto = _texto(dados ?? _json(corpo), corpo);
  if (texto == msgMesaFechada ||
      texto == msgMesaOutroSocio ||
      texto == msgSocioOutraMesa) {
    return RespostaPedido(efeito: EfeitoRespostaPedido.esvaziar, texto: texto);
  }
  if (texto.startsWith(msgMesaFechada) ||
      texto.startsWith(prefixoChavePrimaria)) {
    return const RespostaPedido(
      efeito: EfeitoRespostaPedido.esvaziar,
      texto: msgMesaFechada,
    );
  }
  final visivel = _semPrefixoTecnico(texto);
  return RespostaPedido(
    efeito: EfeitoRespostaPedido.manter,
    texto: visivel.isEmpty ? texto.trim() : visivel,
  );
}

String _texto(Object? dados, String corpo) {
  if (dados is Map &&
      dados.containsKey('Message') &&
      dados['Message'] != null) {
    final mensagem = dados['Message'].toString().trim();
    if (mensagem.isNotEmpty) return mensagem;
  }
  if (dados is String && dados.trim().isNotEmpty) return dados.trim();
  return corpo.trim();
}

Object? _json(String corpo) {
  try {
    return jsonDecode(corpo);
  } catch (_) {
    return null;
  }
}

String _semPrefixoTecnico(String texto) {
  return texto.replaceFirst(RegExp(r'^Error:\s*Status\s*\d*\s*'), '').trim();
}
