import 'package:cardapio_solarium/features/cardapio/produto_regras.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:cardapio_solarium/shared/models/produto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const opcoes = ['Sem gelo', 'Limão', 'Gelo', 'Açúcar', 'Quente'];

  test('monta 5 observações e funde linhas iguais', () {
    var selecao = const SelecaoObservacoes();
    selecao = tocarChip(selecao, 'Sem gelo');
    selecao = tocarChip(selecao, 'Limão');
    selecao = tocarChip(selecao, 'Gelo');

    final longo = 'a' * 50;
    final livre = incluirTextoObservacao(selecao, longo, opcoes);
    expect(livre.limpar, isTrue);
    selecao = livre.selecao;

    final quinto = incluirTextoObservacao(selecao, 'pouco doce', opcoes);
    selecao = quinto.selecao;
    expect(selecao.ordem, ['Sem gelo', 'Limão', 'Gelo', longo, 'pouco doce']);

    final sextoChip = tocarChip(selecao, 'Açúcar');
    expect(sextoChip.aviso, msgLimiteObservacoes);
    expect(sextoChip.ordem, selecao.ordem);

    final sextoTexto = incluirTextoObservacao(selecao, 'outro', opcoes);
    expect(sextoTexto.selecao.aviso, msgLimiteObservacoes);
    expect(sextoTexto.selecao.ordem, selecao.ordem);
    expect(sextoTexto.limpar, isFalse);

    var outra = const SelecaoObservacoes();
    final bateu = incluirTextoObservacao(outra, 'sem gelo', opcoes);
    expect(bateu.selecao.chips, ['Sem gelo']);
    expect(bateu.selecao.livres, isEmpty);
    expect(bateu.limpar, isTrue);

    final repetida = incluirTextoObservacao(bateu.selecao, 'SEM GELO', opcoes);
    expect(repetida.selecao.aviso, msgObservacaoRepetida);
    expect(repetida.limpar, isTrue);
    expect(repetida.selecao.ordem, ['Sem gelo']);

    final vazio = incluirTextoObservacao(bateu.selecao, '   ', opcoes);
    expect(vazio.limpar, isFalse);
    expect(vazio.selecao.ordem, ['Sem gelo']);

    var ordem = const SelecaoObservacoes();
    ordem = tocarChip(ordem, 'Sem gelo');
    ordem = incluirTextoObservacao(ordem, 'bem gelada', opcoes).selecao;
    ordem = tocarChip(ordem, 'Limão');
    expect(ordem.ordem, ['Sem gelo', 'Limão', 'bem gelada']);

    final obs = observacoesDaLinha(ordem.ordem);
    expect(obs, ['Sem gelo', 'Limão', 'bem gelada', '', '']);

    final primeira = fundirNoCarrinho(
      linhas: const [],
      codigo: 10,
      descricao: 'ÁGUA',
      valorUnitario: 4,
      quantidade: 2,
      observacoes: obs,
    );
    expect(primeira.aceita, isTrue);
    expect(primeira.linhas, hasLength(1));
    expect(primeira.linhas.single.quantidade, 2);
    expect(primeira.linhas.single.observacoes, obs);

    final segunda = fundirNoCarrinho(
      linhas: primeira.linhas,
      codigo: 10,
      descricao: 'ÁGUA',
      valorUnitario: 4,
      quantidade: 1,
      observacoes: obs,
    );
    expect(segunda.linhas, hasLength(1));
    expect(segunda.linhas.single.quantidade, 3);
    expect(segunda.quantidadeAntes, 2);

    final diferente = fundirNoCarrinho(
      linhas: segunda.linhas,
      codigo: 10,
      descricao: 'ÁGUA',
      valorUnitario: 4,
      quantidade: 1,
      observacoes: const ['Limão', 'Sem gelo'],
    );
    expect(diferente.linhas, hasLength(2));
    expect(diferente.linhas.last.observacoes.take(2), ['Limão', 'Sem gelo']);

    final cheio = [
      for (var i = 0; i < 25; i++)
        CartLine(
          codigo: i,
          descricao: 'item',
          quantidade: 1,
          valorUnitario: 1,
        ),
    ];
    final recusa = fundirNoCarrinho(
      linhas: cheio,
      codigo: 99,
      descricao: 'novo',
      valorUnitario: 1,
      quantidade: 1,
      observacoes: const [],
    );
    expect(recusa.aceita, isFalse);
    expect(recusa.linhas, hasLength(25));

    final soma = fundirNoCarrinho(
      linhas: cheio,
      codigo: 0,
      descricao: 'item',
      valorUnitario: 1,
      quantidade: 1,
      observacoes: const [],
    );
    expect(soma.aceita, isTrue);
    expect(soma.linhas, hasLength(25));
    expect(soma.linhas.first.quantidade, 2);
  });

  test('glúten e lactose sempre aparecem; vegano e kcal só quando valem', () {
    expect(
      informacoesDoProduto(const Produto()).map((item) => item.texto),
      ['Sem glúten', 'Sem lactose'],
    );
    expect(
      informacoesDoProduto(
        const Produto(
          contemGluten: true,
          contemLactose: true,
          vegano: true,
          kcal: '180',
        ),
      ).map((item) => item.texto),
      ['Contém glúten', 'Contém lactose', 'Vegano', '180 kcal'],
    );
    expect(
      informacoesDoProduto(const Produto(kcal: '0')).map((item) => item.texto),
      isNot(contains('0 kcal')),
    );
    expect(kcalVisivel(''), isNull);
    expect(kcalVisivel('0,0'), isNull);
  });

  test('lista vazia ou não encontrado não vira chip', () {
    expect(lerObservacoes(const [], ''), isEmpty);
    expect(
      lerObservacoes(
        'Observação não encontrada.',
        'Observação não encontrada.',
      ),
      isEmpty,
    );
    expect(
      lerObservacoes(
        [
          {'obs_descricao': 'Sem gelo'},
          {'obs_descricao': '  '},
        ],
        '[]',
      ),
      ['Sem gelo'],
    );
  });
}
