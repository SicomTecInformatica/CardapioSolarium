import 'dart:convert';

import '../../core/acesso/acesso_regras.dart';
import '../../core/format/money.dart';
import '../../core/network/pedido_payload.dart';
import '../../shared/models/conta.dart';
import '../cardapio/cardapio_regras.dart';

const msgContaVazia = 'Nenhum item lançado nesta mesa.';
const msgFaixaMesaFechada = 'Mesa fechada. Solicite o recebimento ao garçom.';
const msgNaoLeuMesa = 'Não foi possível ler a mesa.';
const msgNaoEnviouPagamento = 'Não foi possível enviar o pagamento.';
const msgPagamentoEnviado = 'Pagamento enviado';

const fraseMesaNaoEncontrada = 'Mesa não encontrada.';

class ItensMesa {
  final List<ContaItem> itens;
  final String mensagem;

  const ItensMesa({required this.itens, this.mensagem = ''});

  bool get vazia => itens.isEmpty && mensagem == msgContaVazia;
}

class CabecalhoMesa {
  final Conta? conta;
  final String mensagem;

  const CabecalhoMesa({this.conta, this.mensagem = ''});

  bool get ok => conta != null;
}

class SomaItens {
  final double quantidade;
  final double valor;

  const SomaItens(this.quantidade, this.valor);
}

enum PassoConfirmar { revelarSenha, senhaVazia, confirmar }

class RespostaMesac {
  final bool enviado;
  final String texto;

  const RespostaMesac.enviado()
      : enviado = true,
        texto = '';

  const RespostaMesac.texto(String value)
      : enviado = false,
        texto = value;
}

ItensMesa lerItensMesa(String corpo, Object? dados) {
  if (mesaNaoEncontrada(corpo, dados)) {
    return const ItensMesa(itens: [], mensagem: msgContaVazia);
  }
  if (dados is List) {
    if (dados.isEmpty) {
      return const ItensMesa(itens: [], mensagem: msgContaVazia);
    }
    return ItensMesa(
      itens: [for (final item in dados) ContaItem.fromJson(item)],
    );
  }
  return ItensMesa(itens: const [], mensagem: textoLivre(corpo, dados));
}

CabecalhoMesa lerCabecalhoMesa(String corpo, Object? dados) {
  if (mesaNaoEncontrada(corpo, dados)) {
    return const CabecalhoMesa(mensagem: fraseMesaNaoEncontrada);
  }
  if (dados is Map) {
    return CabecalhoMesa(conta: Conta.fromJson(dados));
  }
  return CabecalhoMesa(mensagem: textoLivre(corpo, dados));
}

bool mesaNaoEncontrada(String corpo, Object? dados) {
  if (dados is String && dados.trim() == fraseMesaNaoEncontrada) return true;
  final texto = corpo.trim();
  if (texto == fraseMesaNaoEncontrada) return true;
  try {
    final decoded = jsonDecode(texto);
    return decoded is String && decoded.trim() == fraseMesaNaoEncontrada;
  } catch (_) {
    return false;
  }
}

String textoLivre(String corpo, Object? dados) {
  if (dados is String && dados.trim().isNotEmpty) {
    return semPrefixoTecnico(dados.trim());
  }
  return semPrefixoTecnico(corpo.trim());
}

SomaItens somarItensConta(List<ContaItem> itens) {
  var quantidade = 0.0;
  var valor = 0.0;
  for (final item in itens) {
    quantidade += item.quantidade;
    valor += item.valor;
  }
  return SomaItens(quantidade, valor);
}

String rodapeConta(SomaItens soma) {
  return '${textoQuantidade(soma.quantidade)} itens · ${reaisNaTela(soma.valor)}';
}

bool faixaMesaFechada({
  required String fechaConta,
  required String referenciaStatus,
  required int mesa,
}) {
  return classificarMesa(
        fechaConta: fechaConta,
        referenciaStatus: referenciaStatus,
        mesaQr: mesa,
      ) ==
      TravaMesa.fechada;
}

bool pagamentoBloqueado(String fechaConta) => fechaConta != '0';

final _aberturaComSegundos = RegExp(
  r'^(\d{2}/\d{2}/\d{4}) (\d{2}:\d{2}):\d{2}$',
);

String formatarAbertura(String abertura) {
  final match = _aberturaComSegundos.firstMatch(abertura.trim());
  if (match == null) return abertura;
  return '${match.group(1)} ${match.group(2)}';
}

String textoTaxa(double taxa) {
  if (taxa == taxa.roundToDouble()) return taxa.round().toString();
  var texto = taxa.toStringAsFixed(2);
  texto = texto.replaceFirst(RegExp(r'0+$'), '');
  texto = texto.replaceFirst(RegExp(r'\.$'), '');
  return texto.replaceAll('.', ',');
}

String rotuloTaxa(double taxa) => 'Taxa de serviço (${textoTaxa(taxa)}%)';

double valorDaTaxa(double consumido, double taxa) {
  return moneyJson(consumido * taxa / 100);
}

double valorPagamento(double consumido, double taxa) {
  return moneyJson(totalComTaxa(consumido, taxa));
}

String rotuloPagar(double total) => 'Pagar · ${reaisNaTela(total)}';

String perguntaPagamento(double total) {
  return 'Enviar o pagamento de ${reaisNaTela(total)}?';
}

PassoConfirmar passoConfirmar({
  required String semSenha,
  required bool senhaVisivel,
  required String senha,
}) {
  if (semSenha == '1') return PassoConfirmar.confirmar;
  if (!senhaVisivel) return PassoConfirmar.revelarSenha;
  if (senha.isEmpty) return PassoConfirmar.senhaVazia;
  return PassoConfirmar.confirmar;
}

bool deveConferirSenha({
  required String senha,
  required bool jaConferida,
}) {
  return !jaConferida && senha.isNotEmpty;
}

bool faltaSenha({
  required String semSenha,
  required String senha,
  required bool jaConferida,
}) {
  return semSenha != '1' && senha.isEmpty && !jaConferida;
}

MesaCPedido pedidoMesac({
  required int local,
  required int mesa,
  required int posicao,
  required String titulo,
  required String nome,
  required int idSocio,
  required double totalComTaxaValor,
}) {
  return MesaCPedido(
    setor: local,
    numMesa: mesa,
    cliente: int.tryParse(titulo.trim()) ?? 0,
    nomeCliente: nome,
    idSocio: idSocio,
    valor: moneyJson(totalComTaxaValor),
    posicao: posicao,
  );
}

RespostaMesac lerRespostaMesac(String corpo) {
  final texto = textoRespostaMesac(corpo);
  if (texto.isEmpty) return const RespostaMesac.enviado();
  return RespostaMesac.texto(texto);
}

String textoRespostaMesac(String corpo) {
  final bruto = corpo.trim();
  if (bruto.isEmpty) return '';
  try {
    final dados = jsonDecode(bruto);
    if (dados == null) return '';
    if (dados is String) return semPrefixoTecnico(dados.trim());
  } catch (_) {}
  return semPrefixoTecnico(bruto);
}

String semPrefixoTecnico(String texto) {
  return texto.replaceFirst(RegExp(r'^Error:\s*Status\s*\d*\s*'), '').trim();
}
