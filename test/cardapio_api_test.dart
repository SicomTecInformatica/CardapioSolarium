import 'dart:typed_data';

import 'package:cardapio_solarium/core/config/app_config.dart';
import 'package:cardapio_solarium/core/network/cardapio_api.dart';
import 'package:cardapio_solarium/core/network/pedido_payload.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Gravador gravador;
  late CardapioApi api;

  setUp(() {
    gravador = _Gravador();
    final dio = Dio()..httpClientAdapter = gravador;
    api = CardapioApi(
      dio: dio,
      config: AppConfig.fromJson(const {
        'IpApiCardapio': 'https://cardapiosicom.azurewebsites.net/api/v1',
        'BaseImagens': 'imagens',
      }),
    );
  });

  test('monta os caminhos GET e normaliza a base com barra', () async {
    expect(api.connectTimeout, CardapioApi.tempoLimite);
    expect(api.receiveTimeout, CardapioApi.tempoLimite);

    const chamadas = <String, String>{
      'setor/setorparametros/2': 'parametros',
      'setor/2': 'setor',
      'Cliente/12345': 'cliente',
      'Cliente/12345/segredo': 'clienteSenha',
      'MesaH/lermesahstatus/70/2/1/12345': 'statusMesa',
      'MesaH/lermesahstatusposicao/70/2/12345': 'statusMesaPosicao',
      'MesaH/70/2/1/12345': 'mesaH',
      'Grupo/2': 'grupos',
      'produto/grupo/10/2': 'produtos',
      'Observacao/10': 'observacoes',
      'MesaI/70/2/1/12345': 'mesaI',
    };

    Future<void> chamar(String nome) {
      switch (nome) {
        case 'parametros':
          return api.parametros(2).then((_) {});
        case 'setor':
          return api.setor(2).then((_) {});
        case 'cliente':
          return api.cliente(12345).then((_) {});
        case 'clienteSenha':
          return api.clienteSenha(12345, 'segredo').then((_) {});
        case 'statusMesa':
          return api.statusMesa(70, 2, 1, 12345).then((_) {});
        case 'statusMesaPosicao':
          return api.statusMesaPosicao(70, 2, 12345).then((_) {});
        case 'mesaH':
          return api.mesaH(70, 2, 1, 12345).then((_) {});
        case 'grupos':
          return api.grupos(2).then((_) {});
        case 'produtos':
          return api.produtos(10, 2).then((_) {});
        case 'observacoes':
          return api.observacoes(10).then((_) {});
        case 'mesaI':
          return api.mesaI(70, 2, 1, 12345).then((_) {});
        default:
          throw StateError(nome);
      }
    }

    for (final entry in chamadas.entries) {
      await chamar(entry.value);
      expect(gravador.ultima?.method, 'GET');
      expect(gravador.ultima?.uri.toString(),
          'https://cardapiosicom.azurewebsites.net/api/v1/${entry.key}');
      expect(gravador.ultima?.uri.query, isEmpty);
      expect(gravador.ultima?.headers['Cache-Control'], 'no-cache');
      expect(gravador.ultima?.headers['Pragma'], 'no-cache');
    }
  });

  test('POST pedido e POST mesac usam o mapa do contrato, sem rede', () async {
    const mesaH = MesaHPedido(
      setor: 2,
      numMesa: 70,
      codLocal: 2,
      posicao: 1,
      socio: '12345',
      idPessoa: '99',
    );
    final itens = [
      CartLine(
          codigo: 22001, descricao: 'AGUA', quantidade: 1, valorUnitario: 4),
    ];
    await api.enviarPedido(mesaH, itens);
    expect(gravador.ultima?.method, 'POST');
    expect(gravador.ultima?.uri.toString(),
        'https://cardapiosicom.azurewebsites.net/api/v1/pedido');
    expect(gravador.ultima?.data, montarPedido(mesaH, itens));
    expect(gravador.ultima?.contentType, Headers.jsonContentType);

    const mesaC = MesaCPedido(
      setor: 2,
      numMesa: 70,
      cliente: 12345,
      nomeCliente: 'Nome do sócio',
      idSocio: 99,
      valor: 52.8,
      posicao: 1,
    );
    await api.enviarConta(mesaC);
    expect(gravador.ultima?.uri.toString(),
        'https://cardapiosicom.azurewebsites.net/api/v1/mesac');
    expect(gravador.ultima?.data, montarMesac(mesaC));
  });

  test('HTTP diferente de 200 não expõe o status e guarda o corpo', () async {
    gravador.statusCode = 500;
    gravador.body = 'Error: Status 500';
    await expectLater(
      api.grupos(2),
      throwsA(
        isA<CardapioApiException>()
            .having((error) => error.message, 'message',
                'Sem conexão. Tente de novo.')
            .having(
                (error) => error.corpoBruto, 'corpoBruto', 'Error: Status 500')
            .having((error) => error.toString(), 'toString',
                isNot(contains('500'))),
      ),
    );
  });

  test('corpo 200 em texto fica disponível para a regra', () async {
    gravador.body = 'Título não encontrado.';
    final resposta = await api.cliente(1);
    expect(resposta.corpoBruto, 'Título não encontrado.');
    expect(resposta.dados, 'Título não encontrado.');
  });
}

class _Gravador implements HttpClientAdapter {
  RequestOptions? ultima;
  int statusCode = 200;
  String body = '[]';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultima = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
