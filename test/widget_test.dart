import 'dart:convert';
import 'dart:typed_data';

import 'package:cardapio_solarium/app.dart';
import 'package:cardapio_solarium/core/config/app_config.dart';
import 'package:cardapio_solarium/core/network/cardapio_api.dart';
import 'package:cardapio_solarium/core/relogio.dart';
import 'package:cardapio_solarium/core/session/app_session.dart';
import 'package:cardapio_solarium/core/theme/club_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entrada = AppBootstrap.fromHref(
    'https://cardapio.exemplo/index.html?70&2',
    agora: DateTime(2026, 11, 9, 18),
    titulo: '777',
  );

  Future<void> abrir(
    WidgetTester tester,
    AppBootstrap bootstrap, {
    _ApiFalsa? api,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig.fromJson(const {
      'IpApiCardapio': 'https://cardapiosicom.azurewebsites.net/api/v1/',
      'BaseImagens': 'imagens/',
      'SemSenha': '0',
      'TempoExpira': 14400,
    });
    final falsa = api ?? _ApiFalsa();
    final cardapio = CardapioApi(
      dio: Dio()..httpClientAdapter = falsa,
      config: config,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapProvider.overrideWithValue(bootstrap),
          appConfigProvider.overrideWithValue(config),
          cardapioApiProvider.overrideWithValue(cardapio),
          relogioProvider.overrideWithValue(() => DateTime(2026, 11, 9, 18)),
        ],
        child: const SolariumApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sem query pede o QR e não oferece acesso', (tester) async {
    await abrir(
      tester,
      AppBootstrap.fromHref(
        'https://cardapio.exemplo/index.html',
        agora: DateTime(2026, 11, 9, 18),
      ),
    );
    expect(find.text('Leia o QR Code da mesa'), findsOneWidget);
    expect(find.text('Acessar'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('reabrir o link com título gravado pede a senha e lê as cores',
      (tester) async {
    await abrir(
      tester,
      AppBootstrap.fromHref(
        'https://cardapio.exemplo/index.html?70&2',
        agora: DateTime(2026, 11, 9, 18),
        titulo: '12345',
      ),
    );
    expect(find.text('Acessar'), findsOneWidget);
    expect(find.byKey(const Key('campo-senha')), findsOneWidget);
    final campo =
        tester.widget<TextField>(find.byKey(const Key('campo-titulo')));
    expect(campo.controller?.text, '12345');
    final contexto = tester.element(find.text('Acessar'));
    expect(Theme.of(contexto).colorScheme.primary, const Color(0xFF112233));
  });

  testWidgets('com query mostra setor, mesa e a cor da API', (tester) async {
    await abrir(tester, entrada);
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('Mesa 70'), findsOneWidget);
    expect(find.text('Posição 1'), findsOneWidget);
    expect(find.text('Acessar'), findsOneWidget);
    expect(find.text('Local 2'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      ),
      findsOneWidget,
    );

    final contexto = tester.element(find.text('Acessar'));
    expect(Theme.of(contexto).colorScheme.primary, const Color(0xFF112233));
    final campo =
        tester.widget<TextField>(find.byKey(const Key('campo-titulo')));
    expect(campo.controller?.text, '777');
  });

  testWidgets('modo MESA esconde a posição e começa em 0', (tester) async {
    await abrir(
      tester,
      entrada,
      api: _ApiFalsa(
        parametros:
            '[{"parametro":"BkColor_Pri","valor":"#112233"},{"parametro":"HabilitaPosicao","valor":"1"},{"parametro":"NomePosicao","valor":"MESA"}]',
      ),
    );
    expect(find.text('Mesa 70'), findsOneWidget);
    expect(find.textContaining('Posição'), findsNothing);
    final container =
        ProviderScope.containerOf(tester.element(find.text('Mesa 70')));
    expect(container.read(appSessionProvider).posicao, 0);
  });

  testWidgets('título vazio avisa no campo e não chama a mesa', (tester) async {
    final api = _ApiFalsa();
    await abrir(tester, entrada, api: api);
    await tester.enterText(find.byKey(const Key('campo-titulo')), '');
    api.caminhos.clear();
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o título'), findsOneWidget);
    expect(api.caminhos.where((caminho) => caminho.contains('MesaH')), isEmpty);
  });

  testWidgets('falha de rede oferece Repetir', (tester) async {
    final api = _ApiFalsa(statusCode: 500);
    await abrir(tester, entrada, api: api);
    expect(find.text('Sem conexão. Tente de novo.'), findsOneWidget);
    expect(find.text('Acessar'), findsNothing);
    api.statusCode = 200;
    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('Acessar'), findsOneWidget);
  });

  testWidgets('local não encontrado desabilita o formulário', (tester) async {
    await abrir(
      tester,
      entrada,
      api: _ApiFalsa(setor: 'Local não encontrado.'),
    );
    expect(find.text('Local não encontrado.'), findsOneWidget);
    final botao = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Acessar'),
    );
    expect(botao.onPressed, isNull);
    final forma = botao.style?.shape?.resolve(const <WidgetState>{});
    expect(forma, isA<RoundedRectangleBorder>());
    expect(
      (forma! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(raioBotao),
    );
    expect(
      botao.style?.backgroundColor?.resolve(const <WidgetState>{}),
      corBotao(const Color(0xFF112233)),
    );
  });

  testWidgets('mesa fechada mostra o aviso do garçom', (tester) async {
    await abrir(
      tester,
      entrada,
      api: _ApiFalsa(
        statusMesa: '{"socio":"777","fechaConta":"1","posicao":70}',
      ),
    );
    await tester.tap(find.text('Acessar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Mesa já fechada. Solicite o recebimento ao garçom.'),
      findsOneWidget,
    );
    expect(find.text('Cardápio na próxima etapa'), findsNothing);
  });

  testWidgets('título inexistente, senha errada e status 99 ficam no campo',
      (tester) async {
    final api = _ApiFalsa()..cliente = 'Título não encontrado.';
    await abrir(tester, entrada, api: api);
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc');
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();
    expect(find.text('Título não encontrado'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo-titulo')))
          .controller
          ?.text,
      isEmpty,
    );

    api.cliente = '{"status":"OK","status_socio":"99","texto":"Ana"}';
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc');
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso indisponível para este título'), findsOneWidget);

    api.cliente = '{"status":"OK","texto":"Ana"}';
    api.senha = 'Sem cadastro.';
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc');
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();
    expect(find.text('Senha inválida'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo-titulo')))
          .controller
          ?.text,
      '12345',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo-senha')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('mesa anterior do mesmo título pergunta se deseja pagar',
      (tester) async {
    final api = _ApiFalsa(
      statusMesa: '{"socio":"12345","fechaConta":"0","posicao":12}',
    );
    await abrir(tester, entrada, api: api);
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc');
    await tester.tap(find.text('Acessar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text(
        'A mesa 12 está aberta para o sócio 12345, '
        'no valor de R\$ 52,80. Deseja pagar a mesa acima?',
      ),
      findsOneWidget,
    );
    expect(
      api.caminhos.where((caminho) => caminho.contains('MesaH/70/2/12/12345')),
      isNotEmpty,
    );

    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(find.text('Cardápio na próxima etapa'), findsNothing);

    await tester.tap(find.text('Acessar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Pagamento enviado'), findsOneWidget);
    expect(find.text('Acessar'), findsOneWidget);
    expect(find.text('Nenhum produto neste local.'), findsNothing);
    expect(api.metodoPost, 'POST');
    expect(
      api.uriPost.toString(),
      'https://cardapiosicom.azurewebsites.net/api/v1/mesac',
    );
    expect(api.corpoPost, {
      'mcl_setor': 2,
      'mcl_nummesa': 70,
      'mcl_Cliente': 12345,
      'mcl_NomeCliente': '',
      'mcl_IdSocio': 9,
      'mcl_Valor': 52.8,
      'mcl_CancServico': 0,
      'mcl_NumFecConta': 0,
      'mcl_vrtxservico': 0.0,
      'rec_codsat': '0',
      'mcl_Posicao': 12,
    });
    expect(jsonEncode(api.corpoPost), isNot(contains('11000')));
    expect(
      api.caminhos.where((caminho) => caminho.contains('Cliente/12345/abc')),
      isNotEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('campo-titulo')))
          .controller
          ?.text,
      '12345',
    );
  });

  testWidgets('mesa anterior sem senha não envia o pagamento', (tester) async {
    final api = _ApiFalsa(
      statusMesa: '{"socio":"12345","fechaConta":"0","posicao":12}',
    );
    await abrir(tester, entrada, api: api);
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.tap(find.text('Acessar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Digite a senha'), findsOneWidget);
    expect(api.corpoPost, isNull);
    expect(find.text('Acessar'), findsOneWidget);
  });

  testWidgets('login entra no cardápio e sair mantém o título', (tester) async {
    await abrir(tester, entrada);
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'segredo');
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum produto neste local.'), findsOneWidget);
    expect(find.textContaining('Mesa 70'), findsOneWidget);
    expect(find.textContaining('Posição 1'), findsOneWidget);

    final antes = ProviderScope.containerOf(
      tester.element(find.textContaining('Mesa 70')),
    );
    antes.read(appSessionProvider.notifier).sair();
    await tester.pumpAndSettle();

    expect(find.text('Nenhum produto neste local.'), findsNothing);
    expect(find.text('Acessar'), findsOneWidget);
    final campo =
        tester.widget<TextField>(find.byKey(const Key('campo-titulo')));
    expect(campo.controller?.text, '12345');
    final container =
        ProviderScope.containerOf(tester.element(find.text('Acessar')));
    final session = container.read(appSessionProvider);
    expect(session.autenticado, isFalse);
    expect(session.titulo, '12345');
    expect(session.nomeSocio, 'Ana');
    expect(session.idSocio, 9);
    expect(
      container.read(sharedPreferencesProvider).getString('titulo'),
      '12345',
    );
  });

  testWidgets('senha com acesso vencido renova e entra no cardápio',
      (tester) async {
    await abrir(
      tester,
      AppBootstrap.fromHref(
        'https://cardapio.exemplo/index.html?70&2',
        agora: DateTime(2026, 11, 9, 10),
        titulo: '777',
      ),
    );
    await tester.enterText(find.byKey(const Key('campo-titulo')), '12345');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'segredo');
    await tester.tap(find.text('Acessar'));
    await tester.pumpAndSettle();

    expect(
      find.text('O acesso expirou. Leia o QR Code novamente.'),
      findsNothing,
    );
    expect(find.text('Nenhum produto neste local.'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.textContaining('Mesa 70')),
    );
    expect(
      container.read(appSessionProvider).horaEntrada,
      DateTime(2026, 11, 9, 18),
    );
  });
}

class _ApiFalsa implements HttpClientAdapter {
  _ApiFalsa({
    this.parametros =
        '[{"parametro":"BkColor_Pri","valor":"#112233"},{"parametro":"parTaxaServico","valor":"10"}]',
    this.setor = '{"descricaoSetor":"Restaurante"}',
    this.statusMesa = 'Mesa não encontrada.',
    this.statusCode = 200,
  });

  String parametros;
  String setor;
  String statusMesa;
  String mesaH = '{"valorConsumido":48,"socio":"12345"}';
  String cliente = '{"status":"OK","texto":"Ana"}';
  String senha = '{"codigo_cliente":1,"id_socio":9}';
  int statusCode;
  final caminhos = <String>[];
  String? metodoPost;
  Uri? uriPost;
  Object? corpoPost;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    caminhos.add(path);
    if (options.method == 'POST' && path.endsWith('/mesac')) {
      metodoPost = options.method;
      uriPost = options.uri;
      corpoPost = options.data;
      return ResponseBody.fromString(
        '',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      _corpo(path),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _corpo(String path) {
    if (path.contains('setorparametros')) return parametros;
    if (path.contains('lermesahstatus')) return statusMesa;
    if (path.contains('Cliente/')) {
      final partes = path.split('Cliente/').last.split('/');
      if (partes.length >= 2 && partes[1].isNotEmpty) return senha;
      return cliente;
    }
    if (path.contains('/setor/')) return setor;
    if (path.contains('MesaH/')) return mesaH;
    return '{}';
  }

  @override
  void close({bool force = false}) {}
}
