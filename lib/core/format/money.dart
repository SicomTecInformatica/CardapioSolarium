import 'package:intl/intl.dart';

final NumberFormat _real = NumberFormat.currency(
  locale: 'pt_BR',
  symbol: r'R$',
  decimalDigits: 2,
);

String formatMoney(num value) => _real.format(value);

double moneyJson(num value) =>
    double.parse(value.toDouble().toStringAsFixed(2));
