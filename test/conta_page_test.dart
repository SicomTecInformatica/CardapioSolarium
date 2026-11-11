import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cardapio_solarium/app.dart';
import 'package:cardapio_solarium/core/acesso/acesso_regras.dart';
import 'package:cardapio_solarium/core/config/app_config.dart';
import 'package:cardapio_solarium/core/network/cardapio_api.dart';
import 'package:cardapio_solarium/core/relogio.dart';
import 'package:cardapio_solarium/core/session/app_session.dart';
import 'package:cardapio_solarium/features/conta/conta_regras.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _SemFoto();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  final agora = DateTime(2026, 11, 9, 18);

  Future<ProviderContainer> abrir(
    WidgetTester tester, {
    required _Api api,
    String semSenha = '0',
    DateTime Function()? relogio,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig.fromJson({
      'IpApiCardapio': 'https://cardapio.exemplo/api/v1/',
      'BaseImagens': 'imagens/',
      'SemSenha': semSenha,
      'TempoExpira': 14400,
    });
    final cardapio = CardapioApi(
      dio: Dio()..httpClientAdapter = api,
      config: config,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapProvider.overrideWithValue(
            AppBootstrap.fromHref(
              'https://cardapio.exemplo/index.html?70&2',
              agora: agora,
            ),
          ),
          appConfigProvider.overrideWithValue(config),
          cardapioApiProvider.overrideWithValue(cardapio),
          relogioProvider.overrideWithValue(relogio ?? () => agora),
        ],
        child: const SolariumApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SolariumApp)),
    );
    container.read(appSessionProvider.notifier).entrar(nome: 'Ana', idSocio: 9);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('a conta lista os itens e a soma', (tester) async {
    final api = _Api(
      mesaI: '['
          '{"itm_produto":10,"itm_descricao":"ÁGUA","itm_quantidade":2,"itm_valor":8},'
          '{"prd":20,"desc":"SUCO","qtd":1,"vlr":5}'
          ']',
    );
    await abrir(tester, api: api);
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();

    expect(find.text('ÁGUA'), findsOneWidget);
    expect(find.text('SUCO'), findsOneWidget);
    expect(_texto(tester, 'qtd-conta-0'), '2');
    expect(_texto(tester, 'qtd-conta-1'), '1');
    expect(_texto(tester, 'valor-conta-0'), reaisNaTela(8));
    expect(_texto(tester, 'valor-conta-1'), reaisNaTela(5));
    expect(_texto(tester, 'rodape-conta'), '3 itens · ${reaisNaTela(13)}');
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      api.caminhos.where((caminho) => caminho.contains('MesaI/70/2/1/')),
      isNotEmpty,
    );
  });

  testWidgets('mesa fechada desabilita o pagamento', (tester) async {
    final api = _Api(
      mesaI:
          '[{"itm_descricao":"ÁGUA","itm_quantidade":1,"itm_valor":4,"itm_produto":10}]',
      statusMesa: '{"socio":"55","fechaConta":"2","posicao":70}',
    );
    await abrir(tester, api: api);
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();

    expect(find.text(msgFaixaMesaFechada), findsOneWidget);
    expect(find.text('ÁGUA'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ir-pagamento')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('pagamento usa a taxa da sessão e envia 110.00', (tester) async {
    final api = _Api(
      mesaH:
          '{"abertura":"10/11/2026 14:30:00","atendente":"João","valorConsumido":100,"socio":"55"}',
      senha: '{"codigo_cliente":1,"id_socio":15}',
    );
    final container = await abrir(tester, api: api);
    final session = container.read(appSessionProvider.notifier);
    await session.definirTitulo('55');
    session.definirTaxa(10);
    await session.adicionarLinha(
      CartLine(
        codigo: 10,
        descricao: 'ÁGUA',
        quantidade: 1,
        valorUnitario: 4,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();

    expect(_texto(tester, 'valor-mesa'), '70');
    expect(_texto(tester, 'valor-abertura'), '10/11/2026 14:30');
    expect(find.text('10/11/2026 14:30:00'), findsNothing);
    expect(_texto(tester, 'valor-atendente'), 'João');
    expect(_texto(tester, 'valor-titulo'), '55');
    expect(_texto(tester, 'valor-nome'), 'Ana');
    expect(_texto(tester, 'valor-consumido'), reaisNaTela(100));
    expect(find.text('Taxa de serviço (10%)'), findsOneWidget);
    expect(_texto(tester, 'valor-taxa'), reaisNaTela(10));
    expect(_texto(tester, 'valor-total'), reaisNaTela(110));
    expect(find.byType(TextField), findsNothing);
    expect(find.text(rotuloPagar(110)), findsOneWidget);

    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pagamento'), findsOneWidget);
    expect(find.byKey(const Key('campo-senha-pagamento')), findsOneWidget);

    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pump();
    expect(find.text('Digite a senha'), findsOneWidget);
    expect(find.textContaining('Enviar o pagamento'), findsNothing);
    expect(api.envios, 0);

    await tester.enterText(
        find.byKey(const Key('campo-senha-pagamento')), 'abc');
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    expect(find.text(perguntaPagamento(110)), findsOneWidget);
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(api.envios, 0);

    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.envios, 1);
    expect(api.metodo, 'POST');
    expect(api.uri.toString(), 'https://cardapio.exemplo/api/v1/mesac');
    expect(api.uri.toString(), isNot(contains('Https_APIPost')));
    expect(api.corpo, {
      'mcl_setor': 2,
      'mcl_nummesa': 70,
      'mcl_Cliente': 55,
      'mcl_NomeCliente': 'Ana',
      'mcl_IdSocio': 15,
      'mcl_Valor': 110.0,
      'mcl_CancServico': 0,
      'mcl_NumFecConta': 0,
      'mcl_vrtxservico': 0.0,
      'rec_codsat': '0',
      'mcl_Posicao': 1,
    });
    expect((api.corpo!['mcl_Valor'] as num).toStringAsFixed(2), '110.00');
    expect(jsonEncode(api.corpo), isNot(contains('11000')));
    expect(find.text(msgPagamentoEnviado), findsOneWidget);

    final estado = container.read(appSessionProvider);
    expect(estado.carrinho, isEmpty);
    expect(estado.titulo, '55');
    expect(estado.nomeSocio, isEmpty);
    expect(estado.idSocio, 0);
    expect(estado.autenticado, isFalse);
    expect(
      container.read(sharedPreferencesProvider).getString('titulo'),
      '55',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('taxa 5% vem da sessão e não de um campo', (tester) async {
    final api = _Api(
      mesaH: '{"abertura":"hoje","atendente":"Lia","valorConsumido":100}',
    );
    final container = await abrir(tester, api: api);
    container.read(appSessionProvider.notifier).definirTaxa(5);
    await tester.pump();
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();

    expect(find.text('Taxa de serviço (5%)'), findsOneWidget);
    expect(_texto(tester, 'valor-taxa'), reaisNaTela(5));
    expect(_texto(tester, 'valor-total'), reaisNaTela(105));
    expect(_texto(tester, 'valor-abertura'), 'hoje');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sem senha confirma direto', (tester) async {
    final api = _Api(
      mesaH:
          '{"abertura":"10/11/2026 14:30:00","atendente":"João","valorConsumido":100}',
    );
    final container = await abrir(tester, api: api, semSenha: '1');
    await container.read(appSessionProvider.notifier).definirTitulo('55');
    container.read(appSessionProvider.notifier).definirTaxa(10);
    await tester.pump();
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text(perguntaPagamento(110)), findsOneWidget);
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(api.envios, 1);
    expect(api.corpo?['mcl_Valor'], 110.0);
    expect(api.corpo?['mcl_IdSocio'], 9);
    expect(
      api.caminhos.where((caminho) => caminho.contains('Cliente/')),
      isEmpty,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('corpo preenchido permanece na tela', (tester) async {
    final api = _Api(
      mesaH:
          '{"valorConsumido":100,"abertura":"10/11/2026 14:30:00","atendente":"João"}',
      mesacCorpo: 'Mesa ocupada',
    );
    final container = await abrir(tester, api: api, semSenha: '1');
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mesa ocupada'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Pagamento'), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, hasLength(1));
    expect(container.read(appSessionProvider).autenticado, isTrue);
  });

  testWidgets('falha de rede ao enviar permanece na tela', (tester) async {
    final api = _Api(
      mesaH: '{"valorConsumido":100,"abertura":"hoje","atendente":"João"}',
      mesacStatus: 500,
    );
    await abrir(tester, api: api, semSenha: '1');
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(msgNaoEnviouPagamento), findsOneWidget);
    expect(find.text('Pagamento'), findsOneWidget);
  });

  testWidgets('releitura fechada não envia', (tester) async {
    final api = _Api(
      mesaH: '{"valorConsumido":100,"abertura":"hoje","atendente":"João"}',
      statusMesa: '{"fechaConta":"0","posicao":1,"socio":"55"}',
      statusNoPost: '{"fechaConta":"1","posicao":3,"socio":"55"}',
    );
    final container = await abrir(tester, api: api, semSenha: '1');
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ir-pagamento')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(msgMesaFechada), findsOneWidget);
    expect(api.envios, 0);
    expect(container.read(appSessionProvider).autenticado, isTrue);
  });

  testWidgets('falha ao reler a mesa avisa e não envia', (tester) async {
    final api = _Api(
      mesaH: '{"valorConsumido":100,"abertura":"hoje","atendente":"João"}',
      falhaStatusNoPost: true,
    );
    await abrir(tester, api: api, semSenha: '1');
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(msgNaoLeuMesa), findsOneWidget);
    expect(api.envios, 0);
    expect(find.text('Pagamento'), findsOneWidget);
  });

  testWidgets('conta expirada volta à entrada e não lê a mesa', (tester) async {
    var momento = agora;
    final api = _Api();
    await abrir(tester, api: api, relogio: () => momento);
    momento = agora.add(const Duration(hours: 5));
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    expect(find.text(msgSessaoExpirada), findsOneWidget);
    expect(api.caminhos.where((caminho) => caminho.contains('MesaI')), isEmpty);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Acessar'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SolariumApp)),
    );
    expect(
      container.read(sharedPreferencesProvider).getString(chaveHoraEntrada),
      isNull,
    );
  });

  testWidgets('pagamento expirado não envia', (tester) async {
    var momento = agora;
    final api = _Api(
      mesaH: '{"valorConsumido":100,"abertura":"hoje","atendente":"João"}',
    );
    await abrir(tester, api: api, semSenha: '1', relogio: () => momento);
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ir-pagamento')));
    await tester.pumpAndSettle();
    momento = agora.add(const Duration(hours: 5));
    final antes = api.envios;
    await tester.tap(find.byKey(const Key('botao-pagar')));
    await tester.pumpAndSettle();
    expect(find.text(msgSessaoExpirada), findsOneWidget);
    expect(api.envios, antes);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Acessar'), findsOneWidget);
  });
}

String _texto(WidgetTester tester, String chave) {
  return tester.widget<Text>(find.byKey(Key(chave))).data ?? '';
}

class _Api implements HttpClientAdapter {
  _Api({
    this.mesaI = '[]',
    this.statusMesa = '{"fechaConta":"0","posicao":1,"socio":"55"}',
    this.mesaH =
        '{"abertura":"10/11/2026 14:30:00","atendente":"João","valorConsumido":100}',
    this.senha = '{"codigo_cliente":1,"id_socio":9}',
    this.mesacCorpo = '',
    this.mesacStatus = 200,
    this.statusNoPost,
    this.falhaStatusNoPost = false,
  });

  String mesaI;
  String statusMesa;
  String? statusNoPost;
  bool falhaStatusNoPost;
  String mesaH;
  String senha;
  String mesacCorpo;
  int mesacStatus;
  final caminhos = <String>[];
  int envios = 0;
  int leiturasStatus = 0;
  String? metodo;
  Uri? uri;
  Map<String, dynamic>? corpo;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    caminhos.add(path);
    if (options.method == 'POST' && path.endsWith('/mesac')) {
      envios++;
      metodo = options.method;
      uri = options.uri;
      corpo = Map<String, dynamic>.from(options.data as Map);
      return ResponseBody.fromString(
        mesacCorpo,
        mesacStatus,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final status = _status(path);
    return ResponseBody.fromString(
      _corpo(path),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  int _status(String path) {
    if (!path.contains('lermesahstatus')) return 200;
    leiturasStatus++;
    if (falhaStatusNoPost && leiturasStatus > 1) return 500;
    return 200;
  }

  String _corpo(String path) {
    if (path.contains('setorparametros')) {
      return '[{"parametro":"parTaxaServico","valor":"10"}]';
    }
    if (path.contains('/setor/')) return '{"descricaoSetor":"Amani"}';
    if (path.contains('MesaI/')) return mesaI;
    if (path.contains('lermesahstatus')) {
      if (statusNoPost != null && leiturasStatus > 1) return statusNoPost!;
      return statusMesa;
    }
    if (path.contains('Cliente/')) return senha;
    if (path.contains('MesaH/')) return mesaH;
    if (path.contains('Grupo/')) return '[]';
    return '{}';
  }

  @override
  void close({bool force = false}) {}
}

class _SemFoto extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _ClienteFoto();
}

class _ClienteFoto extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PedidoFoto();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _PedidoFoto();
}

class _PedidoFoto extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _CabecalhosFoto();

  @override
  Future<HttpClientResponse> close() async => _RespostaFoto();
}

class _CabecalhosFoto extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _RespostaFoto extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 404;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
