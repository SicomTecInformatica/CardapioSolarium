import 'package:cardapio_solarium/features/cardapio/cardapio_regras.dart';
import 'package:cardapio_solarium/shared/models/cart_line.dart';
import 'package:cardapio_solarium/shared/models/produto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busca ignora acento e maiúsculas no nome e nos ingredientes', () {
    final secoes = [
      SecaoCardapio(
        codigoGrupo: 1,
        descricaoGrupo: 'Bebidas',
        falhou: false,
        produtos: const [
          Produto(codigo: 10, descricao: 'ÁGUA', ingredientes: 'Mineral'),
          Produto(codigo: 11, descricao: 'SUCO', ingredientes: ''),
        ],
      ),
      SecaoCardapio(
        codigoGrupo: 2,
        descricaoGrupo: 'Pratos',
        falhou: false,
        produtos: const [
          Produto(codigo: 20, descricao: 'RISOTO', ingredientes: 'Arroz'),
        ],
      ),
    ];

    expect(filtrarCardapio(secoes, 'agua').map((item) => item.produto.codigo),
        [10]);
    expect(
      filtrarCardapio(secoes, 'ÁGUA').single.categoria,
      'Bebidas',
    );
    expect(
      filtrarCardapio(secoes, 'arroz').single.produto.descricao,
      'RISOTO',
    );
    expect(filtrarCardapio(secoes, '   '), isEmpty);
  });

  test('grupo sem produto some e falha de rede permanece', () {
    final secoes = [
      const SecaoCardapio(
        codigoGrupo: 1,
        descricaoGrupo: 'Bebidas',
        produtos: [Produto(codigo: 10, descricao: 'ÁGUA')],
        falhou: false,
      ),
      const SecaoCardapio(
        codigoGrupo: 2,
        descricaoGrupo: 'Doces',
        produtos: [],
        falhou: false,
      ),
      const SecaoCardapio(
        codigoGrupo: 3,
        descricaoGrupo: 'Pratos',
        produtos: [],
        falhou: true,
      ),
    ];

    final visiveis = secoesVisiveis(secoes);
    expect(
        visiveis.map((secao) => secao.descricaoGrupo), ['Bebidas', 'Pratos']);
    expect(mensagemFalhaGrupo('Pratos'), 'Não foi possível carregar Pratos');
  });

  test('lista vazia e grupo não encontrado não viram produtos', () {
    expect(
        lerGrupos('Grupo não encontrado.', '"Grupo não encontrado."'), isEmpty);
    expect(lerProdutos(null, 'Grupo não encontrado.'), isEmpty);
    expect(
      lerGrupos(
        [
          {'codigoGrupo': 4, 'descricaoGrupo': 'Bebidas'},
        ],
        '[]',
      ).single.descricaoGrupo,
      'Bebidas',
    );
    expect(
      lerProdutos(
        [
          {
            'codigo': 10,
            'descricao': 'ÁGUA',
            'preco': 4,
            'ingredientes': 'Fria'
          },
        ],
        '[]',
      ).single.preco,
      4,
    );
  });

  test('a seção visível é a última que cruzou o topo', () {
    expect(secaoVisivel(const [120, 480, 900], 128), 0);
    expect(secaoVisivel(const [40, 120, 480], 128), 1);
    expect(secaoVisivel(const [], 128), 0);
    expect(
      secaoVisivel(const [double.infinity, double.infinity, 200], 128),
      1,
    );
    expect(
      secaoVisivel(
        const [double.infinity, double.infinity],
        128,
        atual: 1,
      ),
      1,
    );
  });

  test('rótulo do pedido distingue um item', () {
    expect(rotuloPedido(1, r'R$ 4,00'), r'Ver pedido · 1 item · R$ 4,00');
    expect(rotuloPedido(2, r'R$ 8,00'), r'Ver pedido · 2 itens · R$ 8,00');
    expect(podeIncluirLinha(25), isFalse);
    expect(podeIncluirLinha(24), isTrue);
    expect(
      contarItens([
        CartLine(quantidade: 1),
        CartLine(quantidade: 2),
      ]),
      3,
    );
  });

  test('cache de 5 minutos ainda vale e o seguinte não', () {
    final em = DateTime(2026, 11, 9, 18);
    expect(cacheFresca(em, em.add(const Duration(minutes: 5))), isTrue);
    expect(
      cacheFresca(em, em.add(const Duration(minutes: 5, seconds: 1))),
      isFalse,
    );
  });

  test('busca produtos com no máximo 4 ao mesmo tempo', () async {
    var ativos = 0;
    var pico = 0;
    final saida = await emFila([
      for (var i = 0; i < 9; i++)
        () async {
          ativos++;
          if (ativos > pico) pico = ativos;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          ativos--;
          return i;
        },
    ]);
    expect(pico, lessThanOrEqualTo(4));
    expect(saida, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
  });
}
