import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/session/app_session.dart';
import 'features/acesso/acesso_page.dart';
import 'features/cardapio/cardapio_page.dart';
import 'features/cardapio/pedido_page.dart';
import 'features/conta/conta_page.dart';
import 'features/conta/pagamento_page.dart';

class _AtualizaRota extends ChangeNotifier {
  void atualizar() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final atualiza = _AtualizaRota();
  ref.listen<bool>(
    appSessionProvider.select((session) => session.autenticado),
    (_, __) => atualiza.atualizar(),
  );
  ref.onDispose(atualiza.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: atualiza,
    redirect: (context, state) {
      final autenticado = ref.read(appSessionProvider).autenticado;
      final path = state.uri.path;
      if (path.endsWith('index.html')) {
        final query = state.uri.query;
        return query.isEmpty ? '/' : '/?$query';
      }
      if (path == '/' && autenticado) return '/cardapio';
      if (path != '/' && !autenticado) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AcessoPage(),
      ),
      GoRoute(
        path: '/cardapio',
        builder: (context, state) => const CardapioPage(),
      ),
      GoRoute(
        path: '/pedido',
        builder: (context, state) => const PedidoPage(),
      ),
      GoRoute(
        path: '/conta',
        builder: (context, state) => const ContaPage(),
      ),
      GoRoute(
        path: '/conta/pagamento',
        builder: (context, state) => const PagamentoPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class SolariumApp extends ConsumerWidget {
  const SolariumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema =
        ref.watch(appSessionProvider.select((session) => session.tema));
    return MaterialApp.router(
      title: 'Solarium Cardápio',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      theme: tema.toThemeData(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
