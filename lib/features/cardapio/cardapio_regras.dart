import '../../shared/models/cart_line.dart';
import '../../shared/models/grupo.dart';
import '../../shared/models/produto.dart';

const validadeCache = Duration(minutes: 5);
const limiteRequisicoes = 4;
const msgLimiteItens = 'Envie o pedido antes de incluir mais itens.';
const msgCardapioVazio = 'Nenhum produto neste local.';
const msgBuscaVazia = 'Nenhum produto encontrado.';

bool cacheFresca(DateTime em, DateTime agora) {
  return agora.difference(em) <= validadeCache;
}

String normalizarBusca(String valor) {
  const origem = 'áàâãäåéèêëíìîïóòôõöúùûüýÿçñ';
  const destino = 'aaaaaaeeeeiiiiooooouuuuyycn';
  final buffer = StringBuffer();
  for (final rune in valor.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final indice = origem.indexOf(char);
    buffer.write(indice >= 0 ? destino[indice] : char);
  }
  return buffer.toString();
}

bool grupoNaoEncontrado(Object? dados, String corpo) {
  if (dados is String && dados.contains('Grupo não encontrado')) return true;
  return corpo.contains('Grupo não encontrado');
}

List<Grupo> lerGrupos(Object? dados, String corpo) {
  if (grupoNaoEncontrado(dados, corpo) || dados is! List) return const [];
  return [for (final item in dados) Grupo.fromJson(item)];
}

List<Produto> lerProdutos(Object? dados, String corpo) {
  if (grupoNaoEncontrado(dados, corpo) || dados is! List) return const [];
  return [for (final item in dados) Produto.fromJson(item)];
}

class SecaoCardapio {
  final int codigoGrupo;
  final String descricaoGrupo;
  final List<Produto> produtos;
  final bool falhou;

  const SecaoCardapio({
    required this.codigoGrupo,
    required this.descricaoGrupo,
    required this.produtos,
    required this.falhou,
  });

  bool get aparece => falhou || produtos.isNotEmpty;

  SecaoCardapio copyWith({
    List<Produto>? produtos,
    bool? falhou,
  }) {
    return SecaoCardapio(
      codigoGrupo: codigoGrupo,
      descricaoGrupo: descricaoGrupo,
      produtos: produtos ?? this.produtos,
      falhou: falhou ?? this.falhou,
    );
  }
}

List<SecaoCardapio> secoesVisiveis(List<SecaoCardapio> secoes) {
  return secoes.where((secao) => secao.aparece).toList();
}

class ItemBusca {
  final int codigoGrupo;
  final String categoria;
  final Produto produto;

  const ItemBusca(this.codigoGrupo, this.categoria, this.produto);
}

List<ItemBusca> filtrarCardapio(List<SecaoCardapio> secoes, String consulta) {
  final termo = normalizarBusca(consulta.trim());
  if (termo.isEmpty) return const [];
  final saida = <ItemBusca>[];
  for (final secao in secoes) {
    if (secao.falhou) continue;
    for (final produto in secao.produtos) {
      final nome = normalizarBusca(produto.descricao);
      final ingredientes = normalizarBusca(produto.ingredientes);
      if (nome.contains(termo) || ingredientes.contains(termo)) {
        saida.add(
          ItemBusca(secao.codigoGrupo, secao.descricaoGrupo, produto),
        );
      }
    }
  }
  return saida;
}

int secaoVisivel(List<double> topos, double linha, {int atual = 0}) {
  if (topos.isEmpty) return 0;
  int? ultimoAcima;
  int? primeiroAbaixo;
  for (var i = 0; i < topos.length; i++) {
    final topo = topos[i];
    if (!topo.isFinite) continue;
    if (topo <= linha) {
      ultimoAcima = i;
    } else {
      primeiroAbaixo ??= i;
    }
  }
  if (ultimoAcima != null) return ultimoAcima;
  if (primeiroAbaixo != null) {
    return primeiroAbaixo == 0 ? 0 : primeiroAbaixo - 1;
  }
  if (atual >= 0 && atual < topos.length) return atual;
  return 0;
}

String rotuloPedido(int quantidade, String total) {
  final itens = quantidade == 1 ? '1 item' : '$quantidade itens';
  return 'Ver pedido · $itens · $total';
}

int contarItens(List<CartLine> linhas) {
  var total = 0.0;
  for (final linha in linhas) {
    total += linha.quantidade;
  }
  return total.round();
}

double somarCarrinho(List<CartLine> linhas) {
  var total = 0.0;
  for (final linha in linhas) {
    total += linha.total;
  }
  return total;
}

bool podeIncluirLinha(int linhasAtuais) => linhasAtuais < 25;

String mensagemFalhaGrupo(String categoria) {
  return 'Não foi possível carregar $categoria';
}

String textoQuantidade(double quantidade) {
  if (quantidade == quantidade.roundToDouble()) {
    return quantidade.round().toString();
  }
  return quantidade.toString();
}

Future<List<T>> emFila<T>(
  List<Future<T> Function()> tarefas, {
  int limite = limiteRequisicoes,
}) async {
  if (tarefas.isEmpty) return <T>[];
  final saida = List<T?>.filled(tarefas.length, null);
  var proximo = 0;
  Future<void> trabalhar() async {
    while (true) {
      final indice = proximo;
      if (indice >= tarefas.length) return;
      proximo = indice + 1;
      saida[indice] = await tarefas[indice]();
    }
  }

  final trabalhadores = limite < tarefas.length ? limite : tarefas.length;
  await Future.wait([for (var i = 0; i < trabalhadores; i++) trabalhar()]);
  return saida.cast<T>();
}
