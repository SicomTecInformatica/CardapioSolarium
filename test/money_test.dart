import 'package:cardapio_solarium/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String tela(num value) => formatMoney(value).replaceAll('\u00A0', ' ');

  test('mostra real com vírgula e duas casas', () {
    expect(tela(4), r'R$ 4,00');
    expect(tela(52.8), r'R$ 52,80');
    expect(tela(1234.5), r'R$ 1.234,50');
  });

  test('grava número JSON com ponto e duas casas', () {
    expect(moneyJson(52.8), 52.8);
    expect(moneyJson(10.126), 10.13);
    expect(moneyJson(4), 4);
  });
}
