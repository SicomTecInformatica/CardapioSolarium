import 'package:flutter_riverpod/flutter_riverpod.dart';

final relogioProvider = Provider<DateTime Function()>((ref) => DateTime.now);
