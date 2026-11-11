import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../shared/models/cart_line.dart';
import 'pedido_payload.dart';
import 'sem_cache.dart';

class ApiResposta {
  final String corpoBruto;
  final Object? dados;

  const ApiResposta({required this.corpoBruto, required this.dados});
}

class CardapioApiException implements Exception {
  final String message;
  final String corpoBruto;

  const CardapioApiException(this.message, {this.corpoBruto = ''});

  @override
  String toString() => message;
}

class CardapioApi {
  CardapioApi({Dio? dio, required AppConfig config}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: config.ipApiCardapio,
      connectTimeout: tempoLimite,
      receiveTimeout: tempoLimite,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null,
    );
  }

  final Dio _dio;

  static const tempoLimite = Duration(seconds: 20);
  static const mensagemRede = 'Sem conexão. Tente de novo.';

  Duration get connectTimeout => _dio.options.connectTimeout ?? Duration.zero;

  Duration get receiveTimeout => _dio.options.receiveTimeout ?? Duration.zero;

  Future<ApiResposta> parametros(Object local) =>
      _get('setor/setorparametros/$local');

  Future<ApiResposta> setor(Object local) => _get('setor/$local');

  Future<ApiResposta> cliente(Object titulo) => _get('Cliente/$titulo');

  Future<ApiResposta> clienteSenha(Object titulo, Object senha) =>
      _get('Cliente/$titulo/$senha');

  Future<ApiResposta> statusMesa(
      Object mesa, Object local, Object posicao, Object titulo) {
    return _get('MesaH/lermesahstatus/$mesa/$local/$posicao/$titulo');
  }

  Future<ApiResposta> statusMesaPosicao(
      Object mesa, Object local, Object titulo) {
    return _get('MesaH/lermesahstatusposicao/$mesa/$local/$titulo');
  }

  Future<ApiResposta> mesaH(
      Object mesa, Object local, Object posicao, Object titulo) {
    return _get('MesaH/$mesa/$local/$posicao/$titulo');
  }

  Future<ApiResposta> grupos(Object local) => _get('Grupo/$local');

  Future<ApiResposta> produtos(Object grupo, Object local) =>
      _get('produto/grupo/$grupo/$local');

  Future<ApiResposta> observacoes(Object grupo) => _get('Observacao/$grupo');

  Future<ApiResposta> mesaI(
      Object mesa, Object local, Object posicao, Object titulo) {
    return _get('MesaI/$mesa/$local/$posicao/$titulo');
  }

  Future<ApiResposta> enviarPedido(MesaHPedido mesaH, List<CartLine> itens) {
    return _post('pedido', montarPedido(mesaH, itens));
  }

  Future<ApiResposta> enviarConta(MesaCPedido mesaC) {
    return _post('mesac', montarMesac(mesaC));
  }

  Future<ApiResposta> _get(String path) => _enviar('GET', path);

  Future<ApiResposta> _post(String path, Map<String, dynamic> data) {
    return _enviar(
      'POST',
      path,
      data: data,
      contentType: Headers.jsonContentType,
    );
  }

  Future<ApiResposta> _enviar(
    String method,
    String path, {
    Object? data,
    String? contentType,
  }) async {
    try {
      final response = await _dio.request<String>(
        path,
        data: data,
        options: Options(
          method: method,
          contentType: contentType,
          headers: cabecalhosSemCache,
          sendTimeout: data == null ? null : tempoLimite,
        ),
      );
      final bruto = response.data ?? '';
      if (response.statusCode != 200) {
        throw CardapioApiException(mensagemRede, corpoBruto: bruto);
      }
      return ApiResposta(corpoBruto: bruto, dados: _decodificar(bruto));
    } on CardapioApiException {
      rethrow;
    } on DioException catch (error) {
      throw CardapioApiException(
        mensagemRede,
        corpoBruto: error.response?.data?.toString() ?? '',
      );
    }
  }

  static Object? _decodificar(String bruto) {
    final text = bruto.trim();
    if (text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return bruto;
    }
  }
}

final cardapioApiProvider = Provider<CardapioApi>((ref) {
  return CardapioApi(config: ref.watch(appConfigProvider));
});
