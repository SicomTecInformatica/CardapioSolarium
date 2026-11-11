import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/acesso/acesso_regras.dart';
import '../../core/config/app_config.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/session/app_session.dart';
import '../../core/session/sessao_guarda.dart';
import 'conta_regras.dart';

enum FimPagamento { enviado, senhaVazia, permaneceu }

/// Pagamento da mesa lida no QR.
///
/// A mensagem ao sócio cita a mesa anterior (`referenciaStatus`).
/// O valor já inclui a taxa. A mesa paga é a do QR, não a citada na frase.
Future<FimPagamento> pagarMesaAtual(
  BuildContext context,
  WidgetRef ref, {
  required double valor,
  required String senha,
  bool senhaConferida = false,
}) async {
  final config = ref.read(appConfigProvider);
  if (sessaoAtualExpirada(ref)) {
    if (context.mounted) await encerrarSessaoExpirada(context, ref);
    return FimPagamento.permaneceu;
  }

  var idSocio = ref.read(appSessionProvider).idSocio;
  if (deveConferirSenha(senha: senha, jaConferida: senhaConferida)) {
    try {
      final resposta = await ref.read(cardapioApiProvider).clienteSenha(
            ref.read(appSessionProvider).titulo,
            senha,
          );
      if (!context.mounted) return FimPagamento.permaneceu;
      final resultado = decidirSenha(resposta.corpoBruto);
      if (resultado.acao == AcaoSenha.invalida ||
          resultado.acao == AcaoSenha.texto) {
        await _aviso(context, resultado.mensagem);
        return FimPagamento.permaneceu;
      }
      idSocio = resultado.idSocio;
      ref.read(appSessionProvider.notifier).definirIdSocio(idSocio);
    } on CardapioApiException catch (erro) {
      if (context.mounted) await _aviso(context, erro.message);
      return FimPagamento.permaneceu;
    }
  } else if (faltaSenha(
    semSenha: config.semSenha,
    senha: senha,
    jaConferida: senhaConferida,
  )) {
    return FimPagamento.senhaVazia;
  }

  if (!context.mounted) return FimPagamento.permaneceu;
  final antes = ref.read(appSessionProvider);
  final api = ref.read(cardapioApiProvider);
  final modo = modoPosicaoMesa(antes.habilitaPosicao, antes.nomePosicao);
  try {
    final statusResp = modo
        ? await api.statusMesaPosicao(antes.mesa, antes.local, antes.titulo)
        : await api.statusMesa(
            antes.mesa,
            antes.local,
            antes.posicao,
            antes.titulo,
          );
    if (!context.mounted) return FimPagamento.permaneceu;
    final status = interpretarStatus(
      corpo: statusResp.corpoBruto,
      modoPosicao: modo,
      titulo: antes.titulo,
      posicaoAtual: antes.posicao,
    );
    if (status.invalido) {
      final texto = status.mensagem.trim().isEmpty
          ? msgNaoLeuMesa
          : status.mensagem.trim();
      await _aviso(context, texto);
      return FimPagamento.permaneceu;
    }
    if (pagamentoBloqueado(status.fechaConta)) {
      await _aviso(context, msgMesaFechada);
      return FimPagamento.permaneceu;
    }
  } on CardapioApiException {
    if (context.mounted) await _aviso(context, msgNaoLeuMesa);
    return FimPagamento.permaneceu;
  }

  if (!context.mounted) return FimPagamento.permaneceu;
  final session = ref.read(appSessionProvider);
  try {
    final resposta = await api.enviarConta(
      pedidoMesac(
        local: session.local,
        mesa: session.mesa,
        posicao: session.posicao,
        titulo: session.titulo,
        nome: session.nomeSocio,
        idSocio: idSocio,
        totalComTaxaValor: valor,
      ),
    );
    if (!context.mounted) return FimPagamento.permaneceu;
    final leitura = lerRespostaMesac(resposta.corpoBruto);
    if (!leitura.enviado) {
      await _aviso(context, leitura.texto);
      return FimPagamento.permaneceu;
    }
  } on CardapioApiException {
    if (context.mounted) await _aviso(context, msgNaoEnviouPagamento);
    return FimPagamento.permaneceu;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(msgPagamentoEnviado)),
    );
  }
  await ref.read(appSessionProvider.notifier).encerrarAposPagamento();
  if (context.mounted) context.go('/');
  return FimPagamento.enviado;
}

Future<void> _aviso(BuildContext context, String mensagem) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
