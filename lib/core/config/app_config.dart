import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../web/url_pagina.dart';

class AppConfig {
  final String ipApiCardapio;
  final String baseImagens;
  final String semSenha;
  final int tempoExpira;
  final String extProd;

  const AppConfig({
    required this.ipApiCardapio,
    required this.baseImagens,
    required this.semSenha,
    required this.tempoExpira,
    required this.extProd,
  });

  static AppConfig? _carregada;

  static Future<AppConfig> load() async {
    final jaCarregada = _carregada;
    if (jaCarregada != null) return jaCarregada;
    final raw =
        await rootBundle.loadString('assets/config/config_cardapio.json');
    final json = jsonDecode(raw);
    final config = AppConfig.fromJson(json);
    _carregada = config;
    return config;
  }

  factory AppConfig.fromJson(dynamic json) {
    final map =
        json is Map ? Map<String, dynamic>.from(json) : <String, dynamic>{};
    return AppConfig(
      ipApiCardapio: _comBarra(_texto(map['IpApiCardapio'])),
      baseImagens: _comBarra(
        _texto(map['BaseImagens']).isEmpty
            ? 'imagens/'
            : _texto(map['BaseImagens']),
      ),
      semSenha: map.containsKey('SemSenha') ? _texto(map['SemSenha']) : '0',
      tempoExpira: _tempo(map['TempoExpira']),
      extProd: _texto(map['ExtProd']).isEmpty ? 'jpg' : _texto(map['ExtProd']),
    );
  }

  String urlFoto(int codigo, {Uri? pagina}) {
    final arquivo = '${baseImagens}produtos/$codigo.$extProd';
    if (baseImagens.startsWith('http')) return arquivo;
    final base = pagina ?? Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') return '';
    return urlNaPagina(arquivo, pagina: base);
  }

  static String _texto(dynamic value) =>
      value == null ? '' : value.toString().trim();

  static int _tempo(dynamic value) {
    if (value == null) return 14400;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 14400;
  }

  static String _comBarra(String value) {
    if (value.isEmpty) return value;
    return value.endsWith('/') ? value : '$value/';
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig ainda não foi carregada');
});
