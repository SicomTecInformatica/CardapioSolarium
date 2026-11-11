import 'dart:convert';

import 'package:cardapio_solarium/core/network/pedido_payload.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('POST pedido usa Hdm_Local como posição e as cinco observações', () {
    final pedido = montarPedido(
      const MesaHPedido(
        setor: 2,
        numMesa: 70,
        codLocal: 2,
        posicao: 1,
        socio: '12345',
        idPessoa: '99',
      ),
      [
        CartLine(
          codigo: 22001,
          descricao: 'AGUA',
          quantidade: 1,
          valorUnitario: 4,
          observacoes: const ['sem gelo', 'limão'],
        ),
      ],
    );

    expect(pedido, {
      'MesaH': {
        'Hdm_setor': 2,
        'Hdm_nummesa': 70,
        'Hdm_codlocal': 2,
        'Hdm_pdv': 9999,
        'Hdm_Local': 1,
        'Hdm_pdvl': 9999,
        'Hdm_MaqFec': 'CELULAR',
        'Hdm_Socio': '12345',
        'Hdm_garcon': 0,
        'Hdm_NomeGarcom': '',
        'Hdm_IdPessoa': '99',
        'hsetor': 2,
        'hnummesa': 70,
        'hcodlocal': 2,
        'hpdv': 9999,
        'hlocal': 1,
        'hpdvl': 9999,
        'hmaqfec': 'CELULAR',
        'hsocio': '12345',
        'hidsocio': '99',
      },
      'mesaItens': [
        {
          'itm_mesa': 70,
          'itm_posicao': 1,
          'itm_socio': '12345',
          'itm_idsocio': '99',
          'itm_produto': 22001,
          'itm_descricao': 'AGUA',
          'itm_quantidade': 1,
          'itm_vlrunit': 4.0,
          'itm_valor': 4.0,
          'itm_observacao1': 'sem gelo',
          'itm_observacao2': 'limão',
          'itm_observacao3': '',
          'itm_observacao4': '',
          'itm_observacao5': '',
          'prd': 22001,
          'desc': 'AGUA',
          'qtd': 1,
          'vlu': 4.0,
          'vlr': 4.0,
          'obs1': 'sem gelo',
          'obs2': 'limão',
          'obs3': '',
          'obs4': '',
          'obs5': '',
        },
      ],
    });
  });

  test('duas linhas levam a posição, a mesa e as cinco observações', () {
    final pedido = montarPedido(
      const MesaHPedido(
        setor: 2,
        numMesa: 70,
        codLocal: 2,
        posicao: 4,
        socio: '12345',
        idPessoa: '99',
      ),
      [
        CartLine(
          codigo: 22001,
          descricao: 'AGUA',
          quantidade: 2,
          valorUnitario: 4,
          observacoes: const ['sem gelo'],
        ),
        CartLine(
          codigo: 33002,
          descricao: 'SUCO',
          quantidade: 1,
          valorUnitario: 8,
        ),
      ],
    );

    final mesa = pedido['MesaH'] as Map<String, dynamic>;
    final itens = pedido['mesaItens'] as List<dynamic>;
    expect(mesa['Hdm_Local'], 4);
    expect(mesa['hlocal'], 4);
    expect(mesa['hnummesa'], 70);
    expect(mesa['hsocio'], '12345');
    expect(itens, hasLength(2));
    expect(itens[0]['itm_posicao'], 4);
    expect(itens[1]['itm_posicao'], 4);
    expect(itens[0]['itm_mesa'], 70);
    expect(itens[1]['itm_mesa'], 70);
    expect(itens[0]['itm_observacao1'], 'sem gelo');
    expect(itens[1]['itm_observacao1'], '');
    for (final item in itens) {
      final mapa = item as Map<String, dynamic>;
      for (var n = 1; n <= 5; n++) {
        expect(mapa['itm_observacao$n'], isA<String>());
      }
    }

    expect(itens[0]['prd'], 22001);
    expect(itens[0]['obs1'], 'sem gelo');
    expect(itens[1]['obs1'], '');

    final bruto = jsonEncode(pedido);
    expect(bruto.contains('|'), isFalse);
    expect(bruto.contains("'"), isFalse);
  });

  test('POST mesac envia o objeto na raiz com os nomes do contrato', () {
    final conta = montarMesac(
      const MesaCPedido(
        setor: 2,
        numMesa: 70,
        cliente: 12345,
        nomeCliente: 'Nome do sócio',
        idSocio: 99,
        valor: 52.8,
        posicao: 1,
      ),
    );

    expect(conta, {
      'mcl_setor': 2,
      'mcl_nummesa': 70,
      'mcl_Cliente': 12345,
      'mcl_NomeCliente': 'Nome do sócio',
      'mcl_IdSocio': 99,
      'mcl_Valor': 52.8,
      'mcl_CancServico': 0,
      'mcl_NumFecConta': 0,
      'mcl_vrtxservico': 0.0,
      'rec_codsat': '0',
      'mcl_Posicao': 1,
    });
  });
}
