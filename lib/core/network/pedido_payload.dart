import '../../core/format/money.dart';
import '../../shared/models/cart_line.dart';

class MesaHPedido {
  final int setor;
  final int numMesa;
  final int codLocal;
  final int posicao;
  final String socio;
  final String idPessoa;

  const MesaHPedido({
    required this.setor,
    required this.numMesa,
    required this.codLocal,
    required this.posicao,
    required this.socio,
    this.idPessoa = '0',
  });

  Map<String, dynamic> toMap() {
    final id = idPessoa.trim().isEmpty ? '0' : idPessoa.trim();
    return {
      'Hdm_setor': setor,
      'Hdm_nummesa': numMesa,
      'Hdm_codlocal': codLocal,
      'Hdm_pdv': 9999,
      'Hdm_Local': posicao,
      'Hdm_pdvl': 9999,
      'Hdm_MaqFec': 'CELULAR',
      'Hdm_Socio': socio,
      'Hdm_garcon': 0,
      'Hdm_NomeGarcom': '',
      'Hdm_IdPessoa': id,
      // A API publicada neste clube vincula estes nomes. Os Hdm_* ficam
      // para o PedidoController novo, que ignora o que não conhece.
      'hsetor': setor,
      'hnummesa': numMesa,
      'hcodlocal': codLocal,
      'hpdv': 9999,
      'hlocal': posicao,
      'hpdvl': 9999,
      'hmaqfec': 'CELULAR',
      'hsocio': socio,
      'hidsocio': id,
    };
  }
}

class MesaCPedido {
  final int setor;
  final int numMesa;
  final int cliente;
  final String nomeCliente;
  final int idSocio;
  final double valor;
  final int cancServico;
  final int numFecConta;
  final double vrtxservico;
  final String recCodsat;
  final int posicao;

  const MesaCPedido({
    required this.setor,
    required this.numMesa,
    required this.cliente,
    required this.nomeCliente,
    required this.idSocio,
    required this.valor,
    this.cancServico = 0,
    this.numFecConta = 0,
    this.vrtxservico = 0,
    this.recCodsat = '0',
    required this.posicao,
  });

  Map<String, dynamic> toMap() {
    return {
      'mcl_setor': setor,
      'mcl_nummesa': numMesa,
      'mcl_Cliente': cliente,
      'mcl_NomeCliente': nomeCliente,
      'mcl_IdSocio': idSocio,
      'mcl_Valor': moneyJson(valor),
      'mcl_CancServico': cancServico,
      'mcl_NumFecConta': numFecConta,
      'mcl_vrtxservico': moneyJson(vrtxservico),
      'rec_codsat': recCodsat,
      'mcl_Posicao': posicao,
    };
  }
}

Map<String, dynamic> montarPedido(MesaHPedido mesaH, List<CartLine> itens) {
  return {
    'MesaH': mesaH.toMap(),
    'mesaItens': [
      for (final item in itens) _itemPedido(mesaH, item),
    ],
  };
}

Map<String, dynamic> montarMesac(MesaCPedido mesaC) => mesaC.toMap();

Map<String, dynamic> _itemPedido(MesaHPedido mesaH, CartLine item) {
  final obs = item.observacoesParaEnvio();
  return {
    'itm_mesa': mesaH.numMesa,
    'itm_posicao': mesaH.posicao,
    'itm_socio': mesaH.socio,
    'itm_idsocio': mesaH.idPessoa.trim().isEmpty ? '0' : mesaH.idPessoa.trim(),
    'itm_produto': item.codigo,
    'itm_descricao': item.descricao,
    'itm_quantidade': item.quantidade,
    'itm_vlrunit': moneyJson(item.valorUnitario),
    'itm_valor': moneyJson(item.total),
    'itm_observacao1': obs[0],
    'itm_observacao2': obs[1],
    'itm_observacao3': obs[2],
    'itm_observacao4': obs[3],
    'itm_observacao5': obs[4],
    'prd': item.codigo,
    'desc': item.descricao,
    'qtd': item.quantidade,
    'vlu': moneyJson(item.valorUnitario),
    'vlr': moneyJson(item.total),
    'obs1': obs[0],
    'obs2': obs[1],
    'obs3': obs[2],
    'obs4': obs[3],
    'obs5': obs[4],
  };
}
