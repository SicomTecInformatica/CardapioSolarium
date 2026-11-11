import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/cart_line.dart';
import '../acesso/acesso_regras.dart';
import '../relogio.dart';
import '../theme/club_theme.dart';
import 'qr_mesa.dart';

const chaveTitulo = 'titulo';
const chaveCarrinho = 'carrinho';
const chaveNomeSocio = 'nomeSocio';
const chaveIdSocio = 'idSocio';
const chaveHoraEntrada = 'horaEntrada';
const chaveMesaEntrada = 'mesaEntrada';
const chaveLocalEntrada = 'localEntrada';

class AppBootstrap {
  final int mesa;
  final int local;
  final bool temQuery;
  final DateTime horaEntrada;
  final String titulo;
  final String nomeSocio;
  final int idSocio;
  final bool autenticado;
  final List<CartLine> carrinho;

  const AppBootstrap({
    required this.mesa,
    required this.local,
    required this.temQuery,
    required this.horaEntrada,
    this.titulo = '',
    this.nomeSocio = '',
    this.idSocio = 0,
    this.autenticado = false,
    this.carrinho = const [],
  });

  factory AppBootstrap.fromHref(
    String href, {
    DateTime? agora,
    String titulo = '',
    String nomeSocio = '',
    int idSocio = 0,
    bool autenticado = false,
    List<CartLine> carrinho = const [],
  }) {
    final qr = parseQrMesa(href);
    return AppBootstrap(
      mesa: qr.mesa,
      local: qr.local,
      temQuery: qr.temQuery,
      horaEntrada: agora ?? DateTime.now(),
      titulo: titulo,
      nomeSocio: nomeSocio,
      idSocio: idSocio,
      autenticado: autenticado,
      carrinho: carrinho.length > 25 ? carrinho.take(25).toList() : carrinho,
    );
  }
}

class AppSessionState {
  final int mesa;
  final int local;
  final int posicao;
  final String titulo;
  final String nomeSocio;
  final int idSocio;
  final DateTime? horaEntrada;
  final double taxa;
  final bool habilitaPosicao;
  final String nomePosicao;
  final bool temQuery;
  final List<CartLine> carrinho;
  final String descricaoSetor;
  final ClubTheme tema;
  final bool autenticado;

  const AppSessionState({
    this.mesa = 0,
    this.local = 0,
    this.posicao = 1,
    this.titulo = '',
    this.nomeSocio = '',
    this.idSocio = 0,
    this.horaEntrada,
    this.taxa = 10,
    this.habilitaPosicao = false,
    this.nomePosicao = '',
    this.temQuery = false,
    this.carrinho = const [],
    this.descricaoSetor = '',
    this.tema = ClubTheme.fallback,
    this.autenticado = false,
  });

  AppSessionState copyWith({
    int? mesa,
    int? local,
    int? posicao,
    String? titulo,
    String? nomeSocio,
    int? idSocio,
    DateTime? horaEntrada,
    double? taxa,
    bool? habilitaPosicao,
    String? nomePosicao,
    bool? temQuery,
    List<CartLine>? carrinho,
    String? descricaoSetor,
    ClubTheme? tema,
    bool? autenticado,
  }) {
    return AppSessionState(
      mesa: mesa ?? this.mesa,
      local: local ?? this.local,
      posicao: posicao ?? this.posicao,
      titulo: titulo ?? this.titulo,
      nomeSocio: nomeSocio ?? this.nomeSocio,
      idSocio: idSocio ?? this.idSocio,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      taxa: taxa ?? this.taxa,
      habilitaPosicao: habilitaPosicao ?? this.habilitaPosicao,
      nomePosicao: nomePosicao ?? this.nomePosicao,
      temQuery: temQuery ?? this.temQuery,
      carrinho: carrinho ?? this.carrinho,
      descricaoSetor: descricaoSetor ?? this.descricaoSetor,
      tema: tema ?? this.tema,
      autenticado: autenticado ?? this.autenticado,
    );
  }
}

class AppSession extends Notifier<AppSessionState> {
  static const limiteLinhas = 25;

  @override
  AppSessionState build() {
    final boot = ref.watch(bootstrapProvider);
    return AppSessionState(
      mesa: boot.mesa,
      local: boot.local,
      posicao: 1,
      titulo: boot.titulo,
      nomeSocio: boot.nomeSocio,
      idSocio: boot.idSocio,
      horaEntrada: boot.horaEntrada,
      taxa: 10,
      habilitaPosicao: false,
      nomePosicao: '',
      temQuery: boot.temQuery,
      carrinho: boot.carrinho,
      autenticado: boot.autenticado,
    );
  }

  void definirMesa(int mesa) => state = state.copyWith(mesa: mesa);

  void definirLocal(int local) => state = state.copyWith(local: local);

  void definirPosicao(int posicao) => state = state.copyWith(posicao: posicao);

  void definirNomeSocio(String nome) => state = state.copyWith(nomeSocio: nome);

  void definirIdSocio(int id) => state = state.copyWith(idSocio: id);

  void definirTaxa(double taxa) => state = state.copyWith(taxa: taxa);

  void definirPosicaoMesa({required bool habilita, required String nome}) {
    state = state.copyWith(habilitaPosicao: habilita, nomePosicao: nome);
  }

  void aplicarClube({
    required ClubTheme tema,
    required double taxa,
    required bool habilitaPosicao,
    required String nomePosicao,
    required String descricaoSetor,
  }) {
    final posicaoInicial =
        modoPosicaoMesa(habilitaPosicao, nomePosicao) ? 0 : state.posicao;
    state = state.copyWith(
      tema: tema,
      taxa: taxa,
      habilitaPosicao: habilitaPosicao,
      nomePosicao: nomePosicao,
      descricaoSetor: descricaoSetor,
      posicao: posicaoInicial,
    );
  }

  Future<void> entrar({required String nome, required int idSocio}) async {
    state = state.copyWith(
      nomeSocio: nome,
      idSocio: idSocio,
      autenticado: true,
    );
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(chaveNomeSocio, nome);
    await prefs.setInt(chaveIdSocio, idSocio);
  }

  Future<void> renovarEntrada() async {
    final agora = ref.read(relogioProvider)();
    state = state.copyWith(horaEntrada: agora);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(chaveMesaEntrada, state.mesa);
    await prefs.setInt(chaveLocalEntrada, state.local);
    await prefs.setString(chaveHoraEntrada, agora.toIso8601String());
  }

  Future<void> esquecerEntrada() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(chaveHoraEntrada);
    await prefs.remove(chaveMesaEntrada);
    await prefs.remove(chaveLocalEntrada);
  }

  void sair() {
    state = state.copyWith(autenticado: false);
  }

  Future<void> definirTitulo(String titulo) async {
    state = state.copyWith(titulo: titulo);
    await ref.read(sharedPreferencesProvider).setString(chaveTitulo, titulo);
  }

  Future<void> adicionarLinha(CartLine linha) async {
    if (state.carrinho.length >= limiteLinhas) return;
    state = state.copyWith(carrinho: [...state.carrinho, linha]);
    await _salvarCarrinho();
  }

  Future<void> removerLinha(int index) async {
    if (index < 0 || index >= state.carrinho.length) return;
    final linhas = [...state.carrinho]..removeAt(index);
    state = state.copyWith(carrinho: linhas);
    await _salvarCarrinho();
  }

  Future<void> removerInstancia(CartLine linha) async {
    final index = state.carrinho.indexWhere((item) => identical(item, linha));
    if (index < 0) return;
    await removerLinha(index);
  }

  Future<void> substituirCarrinho(List<CartLine> linhas) async {
    final limite = linhas.length > limiteLinhas
        ? linhas.take(limiteLinhas).toList()
        : linhas;
    state = state.copyWith(carrinho: limite);
    await _salvarCarrinho();
  }

  Future<void> limparCarrinho() async {
    state = state.copyWith(carrinho: const []);
    await _salvarCarrinho();
  }

  Future<void> encerrarAposPagamento() async {
    state = state.copyWith(
      nomeSocio: '',
      idSocio: 0,
      autenticado: false,
      carrinho: const [],
    );
    await _salvarCarrinho();
  }

  Future<void> _salvarCarrinho() async {
    final raw =
        jsonEncode(state.carrinho.map((linha) => linha.toJson()).toList());
    await ref.read(sharedPreferencesProvider).setString(chaveCarrinho, raw);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences ainda não foi iniciado');
});

final bootstrapProvider = Provider<AppBootstrap>((ref) {
  throw StateError('Entrada do QR ainda não foi lida');
});

final appSessionProvider =
    NotifierProvider<AppSession, AppSessionState>(AppSession.new);
