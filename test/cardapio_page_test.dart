import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cardapio_solarium/app.dart';
import 'package:cardapio_solarium/core/config/app_config.dart';
import 'package:cardapio_solarium/core/network/cardapio_api.dart';
import 'package:cardapio_solarium/core/network/pedido_payload.dart';
import 'package:cardapio_solarium/core/relogio.dart';
import 'package:cardapio_solarium/core/session/app_session.dart';
import 'package:cardapio_solarium/features/cardapio/cardapio_regras.dart';
import 'package:cardapio_solarium/features/cardapio/produto_regras.dart';
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
    required _ApiCardapio api,
    DateTime Function()? relogio,
    DateTime? entrada,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = AppConfig.fromJson(const {
      'IpApiCardapio': 'https://cardapio.exemplo/api/v1/',
      'BaseImagens': 'imagens/',
      'SemSenha': '0',
      'TempoExpira': 14400,
    });
    final cardapio = CardapioApi(
      dio: Dio()..httpClientAdapter = api,
      config: config,
    );
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          bootstrapProvider.overrideWithValue(
            AppBootstrap.fromHref(
              'https://cardapio.exemplo/index.html?70&2',
              agora: entrada ?? agora,
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
    container = ProviderScope.containerOf(
      tester.element(find.byType(SolariumApp)),
    );
    container.read(appSessionProvider.notifier).entrar(nome: 'Ana', idSocio: 9);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('mostra categorias, produtos e a barra ao adicionar',
      (tester) async {
    final api = _ApiCardapio();
    await abrir(tester, api: api);

    expect(find.text('Amani'), findsOneWidget);
    expect(find.textContaining('Mesa 70'), findsOneWidget);
    expect(find.text('Bebidas'), findsWidgets);
    expect(find.text('ÁGUA'), findsOneWidget);
    expect(find.text('Mineral'), findsOneWidget);
    expect(find.textContaining('4,00'), findsOneWidget);
    expect(find.text('Doces'), findsNothing);

    await tester.tap(find.byKey(const Key('adicionar-1-10')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Adicionado'), findsOneWidget);
    expect(find.textContaining('1 item'), findsOneWidget);
    expect(find.textContaining('4,00'), findsWidgets);

    await tester.tap(find.text('Desfazer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('ver-pedido')), findsNothing);
  });

  testWidgets('busca agua acha ÁGUA e esconde os chips', (tester) async {
    await abrir(tester, api: _ApiCardapio());
    await tester.enterText(find.byKey(const Key('busca-cardapio')), 'agua');
    await tester.pump();

    expect(find.text('ÁGUA'), findsOneWidget);
    expect(find.text('RISOTO'), findsNothing);
    expect(find.byKey(const Key('chip-1')), findsNothing);
    expect(find.text('Bebidas'), findsOneWidget);

    await tester.tap(find.byKey(const Key('limpar-busca')));
    await tester.pump();
    expect(find.byKey(const Key('chip-1')), findsOneWidget);
    expect(find.text('RISOTO'), findsOneWidget);
  });

  testWidgets('toque no chip rola até a outra categoria', (tester) async {
    await abrir(tester, api: _ApiCardapio(bebidas: 8));
    final scroll =
        tester.widget<CustomScrollView>(find.byType(CustomScrollView));
    final antes = scroll.controller!.offset;
    await tester.tap(find.byKey(const Key('chip-2')));
    await tester.pumpAndSettle();
    expect(scroll.controller!.offset, greaterThan(antes));
    expect(find.text('RISOTO'), findsOneWidget);
  });

  testWidgets('rolar a lista marca o grupo que está na tela', (tester) async {
    await abrir(tester, api: _ApiCardapio(bebidas: 4, pratos: 14));
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final maximo = controller.position.maxScrollExtent;
    for (var offset = 0.0; offset < maximo; offset += 180) {
      controller.jumpTo(offset);
      await tester.pump();
    }
    controller.jumpTo(maximo);
    await tester.pump();
    await tester.pump();

    final material = tester
        .element(find.byKey(const Key('chip-2')))
        .findAncestorWidgetOfExactType<Material>()!;
    expect(material.color, isNot(Colors.white));
  });

  testWidgets('falha de um grupo oferece repetir só dele', (tester) async {
    final api = _ApiCardapio()..falhaProduto.add('2');
    await abrir(tester, api: api);
    expect(find.text('Não foi possível carregar Pratos'), findsOneWidget);
    expect(find.text('ÁGUA'), findsOneWidget);
    expect(find.byKey(const Key('chip-2')), findsOneWidget);

    api.falhaProduto.clear();
    await tester.tap(find.widgetWithText(TextButton, 'Repetir'));
    await tester.pumpAndSettle();
    expect(find.text('RISOTO'), findsOneWidget);
    expect(find.text('Não foi possível carregar Pratos'), findsNothing);
  });

  testWidgets('falha geral da lista oferece repetir', (tester) async {
    final api = _ApiCardapio()..gruposFalham = true;
    await abrir(tester, api: api);
    expect(find.text('Sem conexão. Tente de novo.'), findsOneWidget);
    expect(find.text('ÁGUA'), findsNothing);

    api.gruposFalham = false;
    await tester.tap(find.text('Repetir'));
    await tester.pumpAndSettle();
    expect(find.text('ÁGUA'), findsOneWidget);
  });

  testWidgets('a 26ª linha avisa e não entra', (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    final session = container.read(appSessionProvider.notifier);
    for (var i = 0; i < 25; i++) {
      await session.adicionarLinha(
        CartLine(
            codigo: 100 + i,
            descricao: 'Item',
            quantidade: 1,
            valorUnitario: 1),
      );
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('adicionar-1-10')));
    await tester.pump();
    expect(find.text(msgLimiteItens), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, hasLength(25));
  });

  testWidgets('o ícone abre a conta e o pedido lista o item', (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    await tester.tap(find.byKey(const Key('abrir-conta')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item lançado nesta mesa.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byTooltip('Voltar'), findsOneWidget);

    container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    expect(find.text('Pedido'), findsOneWidget);
    expect(find.text('ÁGUA'), findsOneWidget);
    expect(find.textContaining('4,00'), findsNWidgets(2));
    expect(find.text('Enviar pedido'), findsOneWidget);
    expect(find.text('Carrinho na próxima etapa'), findsNothing);
  });

  testWidgets('sessão expirada volta à entrada sem buscar o cardápio',
      (tester) async {
    final api = _ApiCardapio();
    await abrir(
      tester,
      api: api,
      entrada: DateTime(2026, 11, 8, 18),
      relogio: () => DateTime(2026, 11, 9, 18),
    );
    expect(find.text('O acesso expirou. Leia o QR Code novamente.'),
        findsOneWidget);
    expect(
        api.caminhos.where((caminho) => caminho.contains('Grupo/')), isEmpty);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Acessar'), findsOneWidget);
  });

  testWidgets('entrar de novo em menos de 5 minutos usa o cache',
      (tester) async {
    final api = _ApiCardapio();
    final container = await abrir(
      tester,
      api: api,
      relogio: () => agora,
    );
    final antes = api.caminhos
        .where((caminho) => caminho.contains('produto/grupo'))
        .length;
    expect(antes, 3);

    container.read(appSessionProvider.notifier).sair();
    await tester.pumpAndSettle();
    container.read(appSessionProvider.notifier).entrar(nome: 'Ana', idSocio: 9);
    await tester.pumpAndSettle();

    final depois = api.caminhos
        .where((caminho) => caminho.contains('produto/grupo'))
        .length;
    expect(depois, antes);
    expect(find.text('ÁGUA'), findsOneWidget);
  });

  testWidgets('o card abre o produto e o mais não abre', (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    await tester.tap(find.byKey(const Key('adicionar-1-10')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('confirmar-produto')), findsNothing);
    expect(find.text('Adicionado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('produto-1-10')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmar-produto')), findsOneWidget);
    expect(find.text('Alguma observação?'), findsOneWidget);
    expect(find.text('Sem glúten'), findsOneWidget);
    expect(find.text('Sem lactose'), findsOneWidget);
    expect(find.text('0/50'), findsOneWidget);
    expect(find.text('Vegano'), findsNothing);

    await tester.tap(find.byKey(const Key('quantidade-mais')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('confirmar-produto')),
        matching: find.textContaining('8,00'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirmar-produto')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(msgAdicionadoPedido), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, hasLength(1));
    expect(container.read(appSessionProvider).carrinho.single.quantidade, 3);
  });

  testWidgets('dois mais do mesmo produto viram uma linha e desfazer volta um',
      (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    await tester.tap(find.byKey(const Key('adicionar-1-10')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('adicionar-1-10')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final linhas = container.read(appSessionProvider).carrinho;
    expect(linhas, hasLength(1));
    expect(linhas.single.quantidade, 2);
    expect(find.textContaining('2 itens'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(appSessionProvider).carrinho.single.quantidade, 1);
  });

  testWidgets('chip de observação entra na linha e o grupo é buscado uma vez',
      (tester) async {
    final api = _ApiCardapio(bebidas: 2)
      ..observacoesCorpo = '[{"obs_descricao":"Sem gelo"},'
          '{"obs_descricao":"Limão"}]';
    final container = await abrir(tester, api: api);

    await tester.tap(find.byKey(const Key('produto-1-10')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('obs-Limão')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('obs-Limão')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('campo-observacao')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-observacao')), 'gelada');
    await tester.tap(find.byKey(const Key('incluir-observacao')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirmar-produto')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final linha = container.read(appSessionProvider).carrinho.single;
    expect(linha.observacoes, ['Limão', 'gelada', '', '', '']);

    await tester.tap(find.byKey(const Key('produto-1-11')));
    await tester.pumpAndSettle();
    expect(find.text('Sem gelo'), findsOneWidget);
    expect(
      api.caminhos.where((caminho) => caminho.contains('Observacao/')).length,
      1,
    );
  });

  testWidgets('a barra abre o pedido e o total acompanha as linhas',
      (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    final session = container.read(appSessionProvider.notifier);
    await session.adicionarLinha(
      CartLine(
        codigo: 10,
        descricao: 'ÁGUA',
        quantidade: 1,
        valorUnitario: 4,
        observacoes: const ['sem gelo', 'limão'],
      ),
    );
    await session.adicionarLinha(
      CartLine(
        codigo: 20,
        descricao: 'SUCO',
        quantidade: 2,
        valorUnitario: 10,
      ),
    );
    await tester.pump();

    expect(find.textContaining('3 itens'), findsOneWidget);
    expect(find.textContaining('24,00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    expect(find.text('Pedido'), findsOneWidget);
    expect(find.text('sem gelo · limão'), findsOneWidget);
    expect(_textoDe(tester, 'preco-linha-0'), contains('4,00'));
    expect(_textoDe(tester, 'preco-linha-1'), contains('20,00'));
    expect(_textoDe(tester, 'total-pedido'), contains('24,00'));

    await tester.tap(find.byKey(const Key('quantidade-mais-0')));
    await tester.pumpAndSettle();
    expect(_textoDe(tester, 'qtd-0'), '2');
    expect(_textoDe(tester, 'preco-linha-0'), contains('8,00'));
    expect(_textoDe(tester, 'total-pedido'), contains('28,00'));

    await tester.tap(find.byKey(const Key('quantidade-menos-0')));
    await tester.pumpAndSettle();
    expect(_textoDe(tester, 'qtd-0'), '1');
    expect(_textoDe(tester, 'total-pedido'), contains('24,00'));
  });

  testWidgets('menos na quantidade 1 só remove depois do sim', (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quantidade-menos-0')));
    await tester.pumpAndSettle();
    expect(find.text('Remover ÁGUA?'), findsOneWidget);

    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(container.read(appSessionProvider).carrinho, hasLength(1));
    expect(_textoDe(tester, 'qtd-0'), '1');
    expect(_textoDe(tester, 'total-pedido'), contains('4,00'));

    await tester.tap(find.byKey(const Key('quantidade-menos-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();
    expect(container.read(appSessionProvider).carrinho, isEmpty);
    expect(find.text('Seu pedido está vazio'), findsOneWidget);
    expect(find.text('Enviar pedido'), findsNothing);

    await tester.tap(find.byKey(const Key('ver-cardapio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ver-pedido')), findsNothing);
    expect(find.text('ÁGUA'), findsOneWidget);
  });

  testWidgets('limpar esvazia, mantém o título e volta ao cardápio',
      (tester) async {
    final container = await abrir(tester, api: _ApiCardapio());
    await container.read(appSessionProvider.notifier).definirTitulo('55');
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('limpar-pedido')));
    await tester.pumpAndSettle();
    expect(find.text('Limpar o pedido?'), findsOneWidget);
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(find.text('Enviar pedido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('limpar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ver-pedido')), findsNothing);
    expect(container.read(appSessionProvider).carrinho, isEmpty);
    expect(container.read(appSessionProvider).titulo, '55');
  });

  testWidgets('envio com corpo vazio usa a posição da sessão e avisa',
      (tester) async {
    final api = _ApiCardapio();
    final container = await abrir(tester, api: api);
    final session = container.read(appSessionProvider.notifier);
    await session.definirTitulo('55');
    session.definirPosicao(3);
    await session.adicionarLinha(
      CartLine(
        codigo: 10,
        descricao: 'ÁGUA',
        quantidade: 2,
        valorUnitario: 4,
        observacoes: const ['sem gelo'],
      ),
    );
    final antes = container.read(appSessionProvider);
    final esperado = montarPedido(
      MesaHPedido(
        setor: antes.local,
        numMesa: antes.mesa,
        codLocal: antes.local,
        posicao: antes.posicao,
        socio: antes.titulo,
        idPessoa: '${antes.idSocio}',
      ),
      antes.carrinho,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    expect(find.text('Enviar o pedido?'), findsOneWidget);
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();
    expect(api.enviosPedido, 0);

    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await _aposEnvio(tester);

    expect(api.enviosPedido, 1);
    expect(api.metodoPedido, 'POST');
    expect(api.caminhos.last, endsWith('/pedido'));
    expect(api.caminhos.last, isNot(contains('Https_APIPostCardapio')));
    expect(api.corpoPedido, esperado);
    expect(find.text('Pedido enviado'), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, isEmpty);
    expect(container.read(appSessionProvider).titulo, '55');
    expect(container.read(appSessionProvider).posicao, 3);
    expect(find.textContaining('Posição 3'), findsOneWidget);
    expect(find.byKey(const Key('ver-pedido')), findsNothing);
  });

  testWidgets('OK| grava a posição e o aviso traz o número', (tester) async {
    final api = _ApiCardapio()..respostaPedido = 'OK|POSICAO=4';
    final container = await abrir(tester, api: api);
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await _aposEnvio(tester);

    expect(find.text('Pedido enviado · posição 4'), findsOneWidget);
    expect(container.read(appSessionProvider).posicao, 4);
    expect(find.textContaining('Posição 4'), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, isEmpty);
  });

  testWidgets('mesa fechada esvazia o carrinho e mantém o título',
      (tester) async {
    final api = _ApiCardapio()
      ..respostaPedido = '{"Message":"Mesa se encontra fechada."}';
    final container = await abrir(tester, api: api);
    await container.read(appSessionProvider.notifier).definirTitulo('55');
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await _aposEnvio(tester);

    expect(find.text('Mesa se encontra fechada.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(container.read(appSessionProvider).carrinho, isEmpty);
    expect(container.read(appSessionProvider).titulo, '55');
    expect(find.byKey(const Key('ver-pedido')), findsNothing);
    expect(find.text('ÁGUA'), findsOneWidget);
  });

  testWidgets('400 com mesa fechada esvazia o carrinho', (tester) async {
    final api = _ApiCardapio()
      ..statusPedido = 400
      ..respostaPedido =
          '{"StatusCode":400,"Message":"Mesa se encontra fechada."}';
    final container = await abrir(tester, api: api);
    await container.read(appSessionProvider.notifier).definirTitulo('55');
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await _aposEnvio(tester);

    expect(find.text('Mesa se encontra fechada.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(container.read(appSessionProvider).carrinho, isEmpty);
    expect(container.read(appSessionProvider).titulo, '55');
  });

  testWidgets('falha de rede mantém o carrinho', (tester) async {
    final api = _ApiCardapio()..statusPedido = 500;
    final container = await abrir(tester, api: api);
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await _aposEnvio(tester);

    expect(
        find.text('Não foi possível enviar. Tente de novo.'), findsOneWidget);
    expect(container.read(appSessionProvider).carrinho, hasLength(1));
    expect(find.text('Enviar pedido'), findsOneWidget);
  });

  testWidgets('sessão expirada não envia o pedido', (tester) async {
    final api = _ApiCardapio();
    var momento = agora;
    final container = await abrir(
      tester,
      api: api,
      relogio: () => momento,
    );
    await container.read(appSessionProvider.notifier).adicionarLinha(
          CartLine(
            codigo: 10,
            descricao: 'ÁGUA',
            quantidade: 1,
            valorUnitario: 4,
          ),
        );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ver-pedido')));
    await tester.pumpAndSettle();
    momento = agora.add(const Duration(hours: 5));

    await tester.tap(find.byKey(const Key('enviar-pedido')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim'));
    await tester.pumpAndSettle();

    expect(find.text('O acesso expirou. Leia o QR Code novamente.'),
        findsOneWidget);
    expect(api.enviosPedido, 0);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Acessar'), findsOneWidget);
  });

  testWidgets('falha das observações deixa o campo livre', (tester) async {
    final api = _ApiCardapio()..observacoesFalham = true;
    await abrir(tester, api: api);
    await tester.tap(find.byKey(const Key('produto-1-10')));
    await tester.pumpAndSettle();
    expect(find.text(msgObservacoesIndisponiveis), findsOneWidget);
    expect(find.text('Alguma observação?'), findsOneWidget);
    expect(find.text('Observações'), findsNothing);
  });
}

String _textoDe(WidgetTester tester, String chave) {
  return tester.widget<Text>(find.byKey(Key(chave))).data ?? '';
}

Future<void> _aposEnvio(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

class _ApiCardapio implements HttpClientAdapter {
  _ApiCardapio({this.bebidas = 1, this.pratos = 1});

  int bebidas;
  int pratos;
  bool gruposFalham = false;
  bool observacoesFalham = false;
  String observacoesCorpo = '[]';
  final falhaProduto = <String>{};
  final caminhos = <String>[];
  int enviosPedido = 0;
  Object? corpoPedido;
  String? metodoPedido;
  String respostaPedido = '';
  int statusPedido = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    caminhos.add(path);
    if (path.endsWith('/pedido')) {
      enviosPedido++;
      metodoPedido = options.method;
      corpoPedido = options.data;
      return ResponseBody.fromString(
        respostaPedido,
        statusPedido,
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
    if (gruposFalham && path.contains('Grupo/')) return 500;
    if (observacoesFalham && path.contains('Observacao/')) return 500;
    if (path.contains('produto/grupo/')) {
      final codigo = path.split('produto/grupo/').last.split('/').first;
      if (falhaProduto.contains(codigo)) return 500;
    }
    return 200;
  }

  String _corpo(String path) {
    if (path.contains('Observacao/')) return observacoesCorpo;
    if (path.contains('produto/grupo/')) {
      final codigo = path.split('produto/grupo/').last.split('/').first;
      if (codigo == '1') {
        final itens = [
          for (var i = 0; i < bebidas; i++)
            '{"codigo":${10 + i},"descricao":"${i == 0 ? 'ÁGUA' : 'SUCO $i'}","preco":4,"ingredientes":"Mineral"}',
        ];
        return '[${itens.join(',')}]';
      }
      if (codigo == '2') {
        final itens = [
          for (var i = 0; i < pratos; i++)
            '{"codigo":${20 + i},"descricao":"${i == 0 ? 'RISOTO' : 'MASSA $i'}","preco":32.5,"ingredientes":"Arroz"}',
        ];
        return '[${itens.join(',')}]';
      }
      return 'Grupo não encontrado.';
    }
    if (path.contains('/setor/')) {
      return '{"descricaoSetor":"Amani"}';
    }
    if (path.contains('Grupo/')) {
      return '[{"codigoGrupo":1,"descricaoGrupo":"Bebidas"},'
          '{"codigoGrupo":2,"descricaoGrupo":"Pratos"},'
          '{"codigoGrupo":3,"descricaoGrupo":"Doces"}]';
    }
    if (path.contains('MesaI/')) return '[]';
    if (path.contains('lermesahstatus')) {
      return '{"fechaConta":"0","posicao":1,"socio":"55"}';
    }
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
