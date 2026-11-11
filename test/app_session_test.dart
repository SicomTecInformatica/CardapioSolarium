import 'dart:convert';

import 'package:cardapio_solarium/core/relogio.dart';
import 'package:cardapio_solarium/core/session/app_session.dart';
import 'package:cardapio_solarium/core/theme/club_theme.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persiste título e carrinho e não grava senha', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWithValue(
          AppBootstrap.fromHref(
            'https://cardapio.exemplo/index.html?70&2',
            agora: DateTime(2026, 11, 9, 18),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final session = container.read(appSessionProvider.notifier);
    expect(container.read(appSessionProvider).posicao, 1);
    expect(container.read(appSessionProvider).taxa, 10);
    expect(container.read(appSessionProvider).horaEntrada,
        DateTime(2026, 11, 9, 18));

    await session.definirTitulo('12345');
    await session.adicionarLinha(
      CartLine(
          codigo: 22001, descricao: 'AGUA', quantidade: 1, valorUnitario: 4),
    );

    expect(prefs.getString('titulo'), '12345');
    final salvo = jsonDecode(prefs.getString('carrinho')!) as List;
    expect(salvo, hasLength(1));
    expect(prefs.getKeys(), isNot(contains('senha')));
  });

  test('a sessão recusa a linha 26', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWithValue(
          AppBootstrap(
            mesa: 1,
            local: 1,
            temQuery: true,
            horaEntrada: DateTime(2026, 11, 9),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(appSessionProvider.notifier);
    for (var i = 0; i < 26; i++) {
      await session.adicionarLinha(CartLine(
          codigo: i, descricao: 'item', quantidade: 1, valorUnitario: 1));
    }
    expect(container.read(appSessionProvider).carrinho, hasLength(25));
  });

  test('modo MESA começa na posição 0 e sair mantém o título', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWithValue(
          AppBootstrap(
            mesa: 70,
            local: 2,
            temQuery: true,
            horaEntrada: DateTime(2026, 11, 9, 18),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final session = container.read(appSessionProvider.notifier);
    session.aplicarClube(
      tema: ClubTheme.fallback,
      taxa: 12,
      habilitaPosicao: true,
      nomePosicao: 'mesa',
      descricaoSetor: 'Restaurante',
    );
    expect(container.read(appSessionProvider).posicao, 0);
    expect(container.read(appSessionProvider).taxa, 12);

    await session.definirTitulo('12345');
    session.entrar(nome: 'Ana', idSocio: 9);
    await session.adicionarLinha(
      CartLine(codigo: 1, descricao: 'AGUA', quantidade: 1, valorUnitario: 4),
    );
    session.sair();

    final estado = container.read(appSessionProvider);
    expect(estado.autenticado, isFalse);
    expect(estado.titulo, '12345');
    expect(estado.nomeSocio, 'Ana');
    expect(prefs.getString('titulo'), '12345');
    expect(estado.carrinho, hasLength(1));
    expect(prefs.getKeys(), isNot(contains('senha')));
  });

  test('entrar grava nome e id e não grava senha', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWithValue(
          AppBootstrap.fromHref(
            'https://cardapio.exemplo/index.html?70&2',
            agora: DateTime(2026, 11, 9, 18),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(appSessionProvider.notifier)
        .entrar(nome: 'Ana', idSocio: 9);
    expect(prefs.getString(chaveNomeSocio), 'Ana');
    expect(prefs.getInt(chaveIdSocio), 9);
    expect(
      prefs.getKeys().any((chave) => chave.toLowerCase().contains('senha')),
      isFalse,
    );
  });

  test('entrar renova a hora para quem estava na senha com acesso vencido',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final agora = DateTime(2026, 11, 9, 18);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        relogioProvider.overrideWithValue(() => agora),
        bootstrapProvider.overrideWithValue(
          AppBootstrap.fromHref(
            'https://cardapio.exemplo/index.html?70&2',
            agora: DateTime(2026, 11, 9, 10),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final session = container.read(appSessionProvider.notifier);
    await session.entrar(nome: 'Ana', idSocio: 9);
    await session.renovarEntrada();

    final estado = container.read(appSessionProvider);
    expect(estado.horaEntrada, agora);
    expect(estado.autenticado, isTrue);
    expect(prefs.getString(chaveHoraEntrada), agora.toIso8601String());
    expect(prefs.getInt(chaveMesaEntrada), 70);
    expect(prefs.getInt(chaveLocalEntrada), 2);
  });
}
