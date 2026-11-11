import 'dart:convert';

import 'package:cardapio_solarium/core/acesso/acesso_regras.dart';
import 'package:cardapio_solarium/core/format/money.dart';
import 'package:cardapio_solarium/core/network/pedido_payload.dart';
import 'package:cardapio_solarium/features/conta/conta_regras.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('total 100 com taxa 10 vira 110.00 numérico', () {
    final total = valorPagamento(100, 10);
    expect(total, 110);
    expect(total.toStringAsFixed(2), '110.00');
    expect(valorDaTaxa(100, 10).toStringAsFixed(2), '10.00');

    final conta = montarMesac(
      pedidoMesac(
        local: 2,
        mesa: 70,
        posicao: 1,
        titulo: '12345',
        nome: 'Ana',
        idSocio: 9,
        totalComTaxaValor: total,
      ),
    );

    expect(conta['mcl_Valor'], isA<double>());
    expect((conta['mcl_Valor'] as double).toStringAsFixed(2), '110.00');
    expect(conta['mcl_Valor'], isNot(11000));
    expect(conta['mcl_Posicao'], 1);
    expect(conta['rec_codsat'], '0');
    expect(conta.containsKey('MesaC'), isFalse);
    expect(jsonEncode(conta), isNot(contains('11000')));
    expect(jsonEncode(conta['mcl_Valor']), isNot(contains('11000')));
  });

  test('abertura com segundos mostra data e hora sem o relógio reconstruído',
      () {
    expect(formatarAbertura('10/11/2026 14:30:00'), '10/11/2026 14:30');
    expect(formatarAbertura('10/11/2026 14:30'), '10/11/2026 14:30');
    expect(formatarAbertura('2026-11-10T14:30:00'), '2026-11-10T14:30:00');
    expect(formatarAbertura('ontem à noite'), 'ontem à noite');
  });

  test('itens aceitam os nomes longos e os curtos', () {
    final longos = lerItensMesa(
      '',
      [
        {
          'itm_produto': 10,
          'itm_descricao': 'ÁGUA',
          'itm_quantidade': 2,
          'itm_valor': 8,
        },
      ],
    );
    expect(longos.itens.single.produto, 10);
    expect(longos.itens.single.descricao, 'ÁGUA');
    expect(longos.itens.single.quantidade, 2);
    expect(longos.itens.single.valor, 8);

    final curtos = lerItensMesa(
      '',
      [
        {'prd': 20, 'desc': 'SUCO', 'qtd': 1, 'vlr': 5},
      ],
    );
    expect(curtos.itens.single.produto, 20);
    expect(curtos.itens.single.descricao, 'SUCO');
    expect(curtos.itens.single.quantidade, 1);
    expect(curtos.itens.single.valor, 5);

    final soma = somarItensConta([...longos.itens, ...curtos.itens]);
    expect(rodapeConta(soma), '3 itens · ${reaisNaTela(13)}');
  });

  test('lista vazia ou mesa não encontrada não bloqueia com diálogo', () {
    expect(lerItensMesa('[]', const []).mensagem, msgContaVazia);
    expect(lerItensMesa('[]', const []).vazia, isTrue);
    expect(
      lerItensMesa('Mesa não encontrada.', 'Mesa não encontrada.').mensagem,
      msgContaVazia,
    );
    expect(msgContaVazia, 'Nenhum item lançado nesta mesa.');
  });

  test('faixa de conta exige a mesma mesa e o post olha só fechaConta', () {
    expect(
      faixaMesaFechada(fechaConta: '1', referenciaStatus: '70', mesa: 70),
      isTrue,
    );
    expect(
      faixaMesaFechada(fechaConta: '1', referenciaStatus: '12', mesa: 70),
      isFalse,
    );
    expect(pagamentoBloqueado('0'), isFalse);
    expect(pagamentoBloqueado('1'), isTrue);
    expect(pagamentoBloqueado('2'), isTrue);
    expect(
        msgFaixaMesaFechada, 'Mesa fechada. Solicite o recebimento ao garçom.');
    expect(
        msgMesaFechada, 'Mesa já fechada. Solicite o recebimento ao garçom.');
  });

  test('senha só aparece quando o clube pede, e o corpo vazio encerra', () {
    expect(
      passoConfirmar(semSenha: '0', senhaVisivel: false, senha: ''),
      PassoConfirmar.revelarSenha,
    );
    expect(
      passoConfirmar(semSenha: '0', senhaVisivel: true, senha: ''),
      PassoConfirmar.senhaVazia,
    );
    expect(
      passoConfirmar(semSenha: '0', senhaVisivel: true, senha: 'abc'),
      PassoConfirmar.confirmar,
    );
    expect(
      passoConfirmar(semSenha: '1', senhaVisivel: false, senha: ''),
      PassoConfirmar.confirmar,
    );
    expect(deveConferirSenha(senha: 'abc', jaConferida: false), isTrue);
    expect(deveConferirSenha(senha: 'abc', jaConferida: true), isFalse);
    expect(deveConferirSenha(senha: '', jaConferida: false), isFalse);
    expect(
      faltaSenha(semSenha: '0', senha: '', jaConferida: false),
      isTrue,
    );
    expect(
      faltaSenha(semSenha: '1', senha: '', jaConferida: false),
      isFalse,
    );

    expect(lerRespostaMesac('').enviado, isTrue);
    expect(lerRespostaMesac('   ').enviado, isTrue);
    expect(lerRespostaMesac('null').enviado, isTrue);
    final texto = lerRespostaMesac('Mesa ocupada');
    expect(texto.enviado, isFalse);
    expect(texto.texto, 'Mesa ocupada');
    expect(
      lerRespostaMesac('Error: Status 200 Mesa ocupada').texto,
      'Mesa ocupada',
    );
    expect(msgPagamentoEnviado, 'Pagamento enviado');
    expect(msgNaoEnviouPagamento, 'Não foi possível enviar o pagamento.');
    expect(msgNaoLeuMesa, 'Não foi possível ler a mesa.');
  });

  test('o valor JSON não nasce de texto com vírgula apagada', () {
    final bruto = jsonEncode(moneyJson(totalComTaxa(100, 10)));
    expect(bruto, '110.0');
    expect(bruto, isNot('11000'));
    expect(bruto.contains(','), isFalse);
  });
}
