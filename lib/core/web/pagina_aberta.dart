import 'package:flutter_riverpod/flutter_riverpod.dart';

/// URL capturada na abertura, antes do router trocar o caminho.
final paginaAbertaProvider = Provider<Uri>((ref) => Uri.base);
