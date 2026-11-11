import '../../shared/models/cart_line.dart';
import '../../shared/models/observacao.dart';
import '../../shared/models/produto.dart';
import 'cardapio_regras.dart';

const limiteObservacoes = 5;
const msgLimiteObservacoes = 'Limite de 5 observações por item.';
const msgObservacaoRepetida = 'Observação já incluída.';
const msgObservacoesIndisponiveis = 'Observações prontas indisponíveis';
const msgAdicionadoPedido = 'Adicionado ao pedido';

enum TipoInformacao { gluten, semGluten, lactose, semLactose, vegano, kcal }

class InformacaoProduto {
  final TipoInformacao tipo;
  final String texto;

  const InformacaoProduto(this.tipo, this.texto);
}

class SelecaoObservacoes {
  final List<String> chips;
  final List<String> livres;
  final String aviso;

  const SelecaoObservacoes({
    this.chips = const [],
    this.livres = const [],
    this.aviso = '',
  });

  List<String> get ordem => [...chips, ...livres];

  int get quantidade => chips.length + livres.length;
}

class TextoIncluido {
  final SelecaoObservacoes selecao;
  final bool limpar;

  const TextoIncluido({required this.selecao, required this.limpar});
}

class CarrinhoAtualizado {
  final List<CartLine> linhas;
  final bool aceita;
  final double quantidadeAntes;

  const CarrinhoAtualizado({
    required this.linhas,
    required this.aceita,
    required this.quantidadeAntes,
  });
}

List<InformacaoProduto> informacoesDoProduto(Produto produto) {
  final kcal = kcalVisivel(produto.kcal);
  return [
    InformacaoProduto(
      produto.contemGluten ? TipoInformacao.gluten : TipoInformacao.semGluten,
      produto.contemGluten ? 'Contém glúten' : 'Sem glúten',
    ),
    InformacaoProduto(
      produto.contemLactose
          ? TipoInformacao.lactose
          : TipoInformacao.semLactose,
      produto.contemLactose ? 'Contém lactose' : 'Sem lactose',
    ),
    if (produto.vegano)
      const InformacaoProduto(TipoInformacao.vegano, 'Vegano'),
    if (kcal != null) InformacaoProduto(TipoInformacao.kcal, '$kcal kcal'),
  ];
}

String? kcalVisivel(String valor) {
  final texto = valor.trim();
  if (texto.isEmpty) return null;
  final numero = double.tryParse(texto.replaceAll(',', '.'));
  if (numero != null && numero == 0) return null;
  return texto;
}

bool observacaoAusente(Object? dados, String corpo) {
  if (dados is String && _naoEncontrada(dados)) return true;
  return _naoEncontrada(corpo);
}

List<String> lerObservacoes(Object? dados, String corpo) {
  if (observacaoAusente(dados, corpo) || dados is! List) return const [];
  final saida = <String>[];
  for (final item in dados) {
    final texto = Observacao.fromJson(item).obsDescricao.trim();
    if (texto.isNotEmpty) saida.add(texto);
  }
  return saida;
}

SelecaoObservacoes tocarChip(SelecaoObservacoes atual, String descricao) {
  final texto = descricao.trim();
  if (texto.isEmpty) return atual;
  final indice = atual.chips.indexOf(texto);
  if (indice >= 0) {
    return SelecaoObservacoes(
      chips: [
        for (var i = 0; i < atual.chips.length; i++)
          if (i != indice) atual.chips[i],
      ],
      livres: atual.livres,
    );
  }
  if (atual.quantidade >= limiteObservacoes) {
    return SelecaoObservacoes(
      chips: atual.chips,
      livres: atual.livres,
      aviso: msgLimiteObservacoes,
    );
  }
  return SelecaoObservacoes(
    chips: [...atual.chips, texto],
    livres: atual.livres,
  );
}

TextoIncluido incluirTextoObservacao(
  SelecaoObservacoes atual,
  String texto,
  List<String> opcoes,
) {
  final limpo = texto.trim();
  if (limpo.isEmpty) {
    return TextoIncluido(selecao: atual, limpar: false);
  }
  final limitado = limpo.length > 50 ? limpo.substring(0, 50) : limpo;
  if (_jaSelecionada(atual, limitado)) {
    return TextoIncluido(
      selecao: SelecaoObservacoes(
        chips: atual.chips,
        livres: atual.livres,
        aviso: msgObservacaoRepetida,
      ),
      limpar: true,
    );
  }
  if (atual.quantidade >= limiteObservacoes) {
    return TextoIncluido(
      selecao: SelecaoObservacoes(
        chips: atual.chips,
        livres: atual.livres,
        aviso: msgLimiteObservacoes,
      ),
      limpar: false,
    );
  }
  for (final opcao in opcoes) {
    if (_igual(opcao, limitado)) {
      return TextoIncluido(
        selecao: SelecaoObservacoes(
          chips: [...atual.chips, opcao],
          livres: atual.livres,
        ),
        limpar: true,
      );
    }
  }
  return TextoIncluido(
    selecao: SelecaoObservacoes(
      chips: atual.chips,
      livres: [...atual.livres, limitado],
    ),
    limpar: true,
  );
}

List<String> observacoesDaLinha(List<String> selecionadas) {
  final uteis = <String>[];
  for (final item in selecionadas) {
    if (item.isEmpty) continue;
    uteis.add(item);
    if (uteis.length == limiteObservacoes) break;
  }
  return List<String>.generate(
    limiteObservacoes,
    (indice) => indice < uteis.length ? uteis[indice] : '',
  );
}

bool mesmasObservacoes(List<String> a, List<String> b) {
  final esquerda = [
    for (final item in a)
      if (item.isNotEmpty) item
  ];
  final direita = [
    for (final item in b)
      if (item.isNotEmpty) item
  ];
  if (esquerda.length != direita.length) return false;
  for (var i = 0; i < esquerda.length; i++) {
    if (esquerda[i] != direita[i]) return false;
  }
  return true;
}

CarrinhoAtualizado fundirNoCarrinho({
  required List<CartLine> linhas,
  required int codigo,
  required String descricao,
  required double valorUnitario,
  required double quantidade,
  required List<String> observacoes,
}) {
  final obs = observacoesDaLinha(observacoes);
  final indice = linhas.indexWhere(
    (linha) =>
        linha.codigo == codigo && mesmasObservacoes(linha.observacoes, obs),
  );
  if (indice >= 0) {
    final atual = linhas[indice];
    return CarrinhoAtualizado(
      aceita: true,
      quantidadeAntes: atual.quantidade,
      linhas: [
        for (var i = 0; i < linhas.length; i++)
          if (i == indice)
            CartLine(
              codigo: atual.codigo,
              descricao: atual.descricao,
              quantidade: atual.quantidade + quantidade,
              valorUnitario: atual.valorUnitario,
              observacoes: obs,
            )
          else
            linhas[i],
      ],
    );
  }
  if (!podeIncluirLinha(linhas.length)) {
    return CarrinhoAtualizado(
      linhas: linhas,
      aceita: false,
      quantidadeAntes: 0,
    );
  }
  return CarrinhoAtualizado(
    aceita: true,
    quantidadeAntes: 0,
    linhas: [
      ...linhas,
      CartLine(
        codigo: codigo,
        descricao: descricao,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        observacoes: obs,
      ),
    ],
  );
}

bool _naoEncontrada(String texto) {
  final normal = texto.toLowerCase();
  return normal.contains('não encontrad') || normal.contains('nao encontrad');
}

bool _igual(String a, String b) => a.toLowerCase() == b.toLowerCase();

bool _jaSelecionada(SelecaoObservacoes atual, String texto) {
  for (final item in atual.chips) {
    if (_igual(item, texto)) return true;
  }
  for (final item in atual.livres) {
    if (_igual(item, texto)) return true;
  }
  return false;
}
