import 'package:cardapio_solarium/core/session/qr_mesa.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê mesa e local de index.html?70&2', () {
    final qr = parseQrMesa('https://cardapio.exemplo/index.html?70&2');
    expect(qr.mesa, 70);
    expect(qr.local, 2);
    expect(qr.temQuery, isTrue);
  });

  test('ignora o terceiro valor da query', () {
    final qr = parseQrMesa('https://cardapio.exemplo/index.html?70&2&9');
    expect(qr.mesa, 70);
    expect(qr.local, 2);
  });

  test('sem query a mesa e o local ficam em zero', () {
    final qr = parseQrMesa('https://cardapio.exemplo/index.html');
    expect(qr.mesa, 0);
    expect(qr.local, 0);
    expect(qr.temQuery, isFalse);
  });

  test('não interpreta nomes de parâmetro', () {
    final qr =
        parseQrMesa('https://cardapio.exemplo/index.html?mesa=70&local=2');
    expect(qr.mesa, 0);
    expect(qr.local, 0);
    expect(qr.temQuery, isTrue);
  });
}
