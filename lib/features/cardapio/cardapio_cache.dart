import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/grupo.dart';
import '../../shared/models/produto.dart';
import 'cardapio_regras.dart';

class ProdutosGuardados {
  final DateTime em;
  final List<Produto> produtos;
  final bool falhou;

  const ProdutosGuardados({
    required this.em,
    required this.produtos,
    required this.falhou,
  });
}

class CacheCardapioState {
  final int? local;
  final DateTime? gruposEm;
  final List<Grupo> grupos;
  final Map<int, ProdutosGuardados> produtos;

  const CacheCardapioState({
    this.local,
    this.gruposEm,
    this.grupos = const [],
    this.produtos = const {},
  });
}

class CacheCardapio extends Notifier<CacheCardapioState> {
  @override
  CacheCardapioState build() => const CacheCardapioState();

  bool gruposFrescos(int local, DateTime agora) {
    final em = state.gruposEm;
    return state.local == local && em != null && cacheFresca(em, agora);
  }

  ProdutosGuardados? produtosFrescos(int local, int codigo, DateTime agora) {
    if (state.local != local) return null;
    final guardado = state.produtos[codigo];
    if (guardado == null || guardado.falhou) return null;
    if (!cacheFresca(guardado.em, agora)) return null;
    return guardado;
  }

  void guardarGrupos(int local, List<Grupo> grupos, DateTime em) {
    final mesmoLocal = state.local == local;
    state = CacheCardapioState(
      local: local,
      gruposEm: em,
      grupos: grupos,
      produtos: mesmoLocal ? state.produtos : const {},
    );
  }

  void guardarProdutos({
    required int local,
    required int codigoGrupo,
    required List<Produto> produtos,
    required bool falhou,
    required DateTime em,
  }) {
    if (state.local != local) return;
    state = CacheCardapioState(
      local: state.local,
      gruposEm: state.gruposEm,
      grupos: state.grupos,
      produtos: {
        ...state.produtos,
        codigoGrupo: ProdutosGuardados(
          em: em,
          produtos: produtos,
          falhou: falhou,
        ),
      },
    );
  }
}

final cacheCardapioProvider =
    NotifierProvider<CacheCardapio, CacheCardapioState>(CacheCardapio.new);

class CacheObservacoes extends Notifier<Map<int, List<String>>> {
  @override
  Map<int, List<String>> build() => const {};

  List<String>? ler(int codigoGrupo) => state[codigoGrupo];

  void guardar(int codigoGrupo, List<String> itens) {
    state = {
      ...state,
      codigoGrupo: List<String>.unmodifiable(itens),
    };
  }
}

final cacheObservacoesProvider =
    NotifierProvider<CacheObservacoes, Map<int, List<String>>>(
  CacheObservacoes.new,
);
