import 'package:cardapio_solarium/core/network/pedido_resposta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('corpo vazio é pedido enviado', () {
    final leitura = lerRespostaPedido('');
    expect(leitura.efeito, EfeitoRespostaPedido.sucesso);
    expect(leitura.posicao, isNull);
  });

  test('OK|POSICAO=4 grava a posição', () {
    final leitura = lerRespostaPedido('OK|POSICAO=4');
    expect(leitura.efeito, EfeitoRespostaPedido.sucesso);
    expect(leitura.posicao, 4);
  });

  test('as três mensagens conhecidas esvaziam o carrinho', () {
    const frases = [
      'Mesa se encontra fechada.',
      'Mesa se encontra aberta em outro sócio.',
      'Socio já esta logado em outra mesa.',
    ];
    for (final frase in frases) {
      final leitura = lerRespostaPedido('{"Message":"$frase"}');
      expect(leitura.efeito, EfeitoRespostaPedido.esvaziar);
      expect(leitura.texto, frase);
    }
  });

  test('violação de chave primária vira mesa fechada', () {
    const corpo = '{"Message":"Erro ao gravar pedido. Violação da restrição '
        "PRIMARY KEY 'PK_MESAH' na MESAH.\"}";
    final leitura = lerRespostaPedido(corpo);
    expect(leitura.efeito, EfeitoRespostaPedido.esvaziar);
    expect(leitura.texto, 'Mesa se encontra fechada.');
  });

  test('outro texto permanece no carrinho, sem o prefixo técnico', () {
    final leitura = lerRespostaPedido('Error: Status 500 mesa ocupada');
    expect(leitura.efeito, EfeitoRespostaPedido.manter);
    expect(leitura.texto, 'mesa ocupada');
    expect(leitura.texto.contains('Error: Status'), isFalse);
  });
}
