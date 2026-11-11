import 'package:cardapio_solarium/core/network/posicao_resposta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê a posição depois de OK|', () {
    expect(parsePosicaoOk('"OK|POSICAO=3"'), 3);
    expect(parsePosicaoOk('OK|POSICAO=12\n'), 12);
    expect(parsePosicaoOk("'\rOK|POSICAO=7\n'"), 7);
  });

  test('devolve nulo quando o corpo não começa com OK|', () {
    expect(parsePosicaoOk('Mesa se encontra fechada.'), isNull);
    expect(parsePosicaoOk(''), isNull);
    expect(parsePosicaoOk('ok|POSICAO=1'), isNull);
    expect(parsePosicaoOk('OK|OUTRO=1'), isNull);
  });
}
