import 'package:flutter/material.dart';

import '../web/url_pagina.dart';

class ClubTheme {
  final Color primary;
  final Color surface;
  final Color pageBackground;
  final Color text;
  final Color textSecondary;
  final Color card;
  final double radius;
  final String? fontFamily;
  final LinearGradient? background;
  final Color buttonText;
  final String? logoUrl;
  final String? fundoUrl;

  const ClubTheme({
    required this.primary,
    required this.surface,
    required this.pageBackground,
    required this.text,
    required this.textSecondary,
    required this.card,
    required this.radius,
    this.fontFamily,
    this.background,
    this.buttonText = Colors.white,
    this.logoUrl,
    this.fundoUrl,
  });

  static const fallback = ClubTheme(
    primary: Color(0xFF005495),
    surface: Colors.white,
    pageBackground: Color(0xFFF6F6F6),
    text: Color(0xFF222222),
    textSecondary: Color(0xFF6B6B6B),
    card: Colors.white,
    radius: 12,
  );

  ThemeData toThemeData() {
    final family = (fontFamily == null || fontFamily!.trim().isEmpty)
        ? 'Roboto'
        : fontFamily!.trim();
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        onPrimary: buttonText,
        surface: surface,
        onSurface: text,
      ),
      scaffoldBackgroundColor: pageBackground,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

ClubTheme temaDoClube(
  Map<String, String> parametros, {
  required String baseImagens,
  Uri? pagina,
}) {
  final fonte = parametros['FontesGeral']?.trim();
  return ClubTheme(
    primary: corHex(parametros['BkColor_Pri']) ?? ClubTheme.fallback.primary,
    surface: corHex(parametros['BkColor_Sec']) ?? ClubTheme.fallback.surface,
    pageBackground: ClubTheme.fallback.pageBackground,
    text: ClubTheme.fallback.text,
    textSecondary: ClubTheme.fallback.textSecondary,
    card: ClubTheme.fallback.card,
    radius: ClubTheme.fallback.radius,
    fontFamily: (fonte == null || fonte.isEmpty) ? null : fonte,
    background: gradientFromBackground(parametros['BackGround']),
    buttonText: corHex(parametros['Color_Bot']) ?? Colors.white,
    logoUrl: resolverUrlImagem(
      parametros['ImgLogo'],
      baseImagens: baseImagens,
      pagina: pagina,
    ),
    fundoUrl: resolverUrlImagem(
      parametros['ImgFundo'],
      baseImagens: baseImagens,
      pagina: pagina,
    ),
  );
}

Color? corHex(String? valor) {
  if (valor == null) return null;
  var body = valor.trim();
  if (body.isEmpty) return null;
  if (body.startsWith('#')) body = body.substring(1);
  if (body.length == 3) {
    body = body.split('').map((char) => '$char$char').join();
  }
  if (body.length == 6) body = 'FF$body';
  if (body.length != 8) return null;
  final parsed = int.tryParse(body, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

String? resolverUrlImagem(
  String? caminho, {
  required String baseImagens,
  Uri? pagina,
}) {
  final valor = caminho?.trim() ?? '';
  if (valor.isEmpty) return null;
  if (_ehHttp(valor)) return valor;

  final arquivo = valor.startsWith('/') ? valor.substring(1) : valor;
  final base = baseImagens.trim();
  if (base.isEmpty) return _naOrigem(arquivo, pagina);

  if (_ehHttp(base)) {
    final baseNorm = base.endsWith('/') ? base : '$base/';
    final uri = Uri.parse(baseNorm);
    final pasta = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
    if (pasta.isNotEmpty && arquivo.startsWith(pasta)) {
      return '${uri.origin}/$arquivo';
    }
    return '$baseNorm$arquivo';
  }

  final baseNorm = base.endsWith('/') ? base : '$base/';
  final pasta = baseNorm.startsWith('/') ? baseNorm.substring(1) : baseNorm;
  final relativo = arquivo.startsWith(pasta) ? arquivo : '$baseNorm$arquivo';
  return _naOrigem(relativo, pagina);
}

String _naOrigem(String relativo, Uri? pagina) {
  return urlNaPagina(relativo, pagina: pagina);
}

bool _ehHttp(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

/// Cantos curtos, no estilo Goomer: quase quadrados, sem formato de cápsula.
const double raioBotao = 6;

BorderRadius get bordaBotao => BorderRadius.circular(raioBotao);

RoundedRectangleBorder formatoBotao({BorderSide side = BorderSide.none}) {
  return RoundedRectangleBorder(borderRadius: bordaBotao, side: side);
}

/// Primária do clube, mais clara e com menos saturação.
Color corBotao(Color primaria) {
  final hsl = HSLColor.fromColor(primaria);
  final luz = (hsl.lightness + 0.10).clamp(0.0, 0.68);
  final saturacao = hsl.saturation * 0.62;
  return hsl.withLightness(luz).withSaturation(saturacao).toColor();
}

Color corLegivelNoFundo(Color fundo, Color preferida) {
  final distancia =
      (preferida.computeLuminance() - fundo.computeLuminance()).abs();
  if (distancia >= 0.35) return preferida;
  return fundo.computeLuminance() > 0.55
      ? const Color(0xFF222222)
      : Colors.white;
}

LinearGradient? gradientFromBackground(String? css) {
  if (css == null || css.trim().isEmpty) return null;
  final colors = RegExp(r'#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})(?![0-9A-Fa-f])')
      .allMatches(css)
      .map((match) => _hex(match.group(0)!))
      .toList();
  if (colors.length < 2) return null;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [colors[0], colors[1]],
  );
}

Color _hex(String hex) {
  var body = hex.replaceFirst('#', '');
  if (body.length == 3) {
    body = body.split('').map((char) => '$char$char').join();
  }
  return Color(0xFF000000 | int.parse(body, radix: 16));
}
