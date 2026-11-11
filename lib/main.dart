import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/session/app_session.dart';
import 'core/session/qr_mesa.dart';
import 'core/session/sessao_inicial.dart';
import 'core/web/page_href.dart';
import 'core/web/pagina_aberta.dart';
import 'core/web/url_strategy.dart';
import 'shared/models/cart_line.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final href = pageHref();
  final agora = DateTime.now();
  configurePathUrlStrategy();
  final config = await AppConfig.load();
  final prefs = await SharedPreferences.getInstance();
  final inicial = decidirSessaoInicial(
    qr: parseQrMesa(href),
    agora: agora,
    tempoExpira: config.tempoExpira,
    titulo: prefs.getString(chaveTitulo) ?? '',
    nomeSocio: prefs.getString(chaveNomeSocio) ?? '',
    idSocio: prefs.getInt(chaveIdSocio) ?? 0,
    mesaGravada: prefs.getInt(chaveMesaEntrada),
    localGravado: prefs.getInt(chaveLocalEntrada),
    horaGravada: DateTime.tryParse(prefs.getString(chaveHoraEntrada) ?? ''),
  );
  if (inicial.gravarEntrada) {
    await prefs.setInt(chaveMesaEntrada, inicial.mesa);
    await prefs.setInt(chaveLocalEntrada, inicial.local);
    await prefs.setString(
      chaveHoraEntrada,
      inicial.horaEntrada.toIso8601String(),
    );
  }
  final entrada = AppBootstrap(
    mesa: inicial.mesa,
    local: inicial.local,
    temQuery: inicial.temQuery,
    horaEntrada: inicial.horaEntrada,
    titulo: prefs.getString(chaveTitulo) ?? '',
    nomeSocio: inicial.nomeSocio,
    idSocio: inicial.idSocio,
    autenticado: inicial.autenticado,
    carrinho: CartLine.listFromStorage(prefs.getString(chaveCarrinho)),
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(prefs),
        bootstrapProvider.overrideWithValue(entrada),
        paginaAbertaProvider.overrideWithValue(_pagina(href)),
      ],
      child: const SolariumApp(),
    ),
  );
}

Uri _pagina(String href) => Uri.tryParse(href) ?? Uri.base;
