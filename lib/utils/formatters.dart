import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(
  locale: 'ja_JP',
  symbol: '¥',
  decimalDigits: 0,
);

final dateFormat = DateFormat.yMMMd();

final monthFormat = DateFormat.yMMMM();
