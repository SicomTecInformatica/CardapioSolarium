import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/format/money.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/network/pedido_payload.dart';
import '../../core/network/pedido_resposta.dart';
import '../../core/session/app_session.dart';
import '../../core/session/sessao_guarda.dart';
import '../../core/web/pagina_aberta.dart';
import '../../core/theme/club_theme.dart';
import '../../shared/models/cart_line.dart';
import 'cardapio_regras.dart';
import 'foto_produto.dart';

const msgFalhaEnvio = 'Não foi possível enviar. Tente de novo.';

class PedidoPage extends ConsumerStatefulWidget {
  const PedidoPage({super.key});

  @override
  ConsumerState<PedidoPage> createState() => _PedidoPageState();
}

class _PedidoPageState extends ConsumerState<PedidoPage> {
  bool _enviando = false;

  Future<void> _mudarQuantidade(int index, int delta) async {
    if (_enviando) return;
    final linhas = ref.read(appSessionProvider).carrinho;
    if (index < 0 || index >= linhas.length) return;
    final atual = linhas[index];
    if (delta < 0 && atual.quantidade <= 1) {
      final remover = await _simNao('Remover ${atual.descricao}?');
      if (!remover || !mounted) return;
      await ref.read(appSessionProvider.notifier).removerLinha(index);
      return;
    }
    final novas = [
      for (var i = 0; i < linhas.length; i++)
        if (i == index)
          CartLine(
            codigo: atual.codigo,
            descricao: atual.descricao,
            quantidade: atual.quantidade + delta,
            valorUnitario: atual.valorUnitario,
            observacoes: atual.observacoes,
          )
        else
          linhas[i],
    ];
    await ref.read(appSessionProvider.notifier).substituirCarrinho(novas);
  }

  Future<void> _limpar() async {
    if (_enviando) return;
    final confirmou = await _simNao('Limpar o pedido?');
    if (!confirmou || !mounted) return;
    final gravacao = ref.read(appSessionProvider.notifier).limparCarrinho();
    _voltarCardapio();
    await gravacao;
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final confirmou = await _simNao('Enviar o pedido?');
    if (!confirmou || !mounted || _enviando) return;
    if (sessaoAtualExpirada(ref)) {
      await _expirou();
      return;
    }
    final session = ref.read(appSessionProvider);
    if (session.carrinho.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final resposta = await ref.read(cardapioApiProvider).enviarPedido(
            _mesa(session),
            session.carrinho,
          );
      if (!mounted) return;
      await _aplicar(
        lerRespostaPedido(resposta.corpoBruto, dados: resposta.dados),
      );
    } on CardapioApiException catch (erro) {
      _pararEnvio();
      if (!mounted) return;
      final corpo = erro.corpoBruto.trim();
      if (corpo.isEmpty) {
        await _aviso(msgFalhaEnvio);
        return;
      }
      await _aplicar(lerRespostaPedido(corpo));
    } catch (_) {
      _pararEnvio();
      if (!mounted) return;
      await _aviso(msgFalhaEnvio);
    } finally {
      _pararEnvio();
    }
  }

  Future<void> _aplicar(RespostaPedido leitura) async {
    _pararEnvio();
    switch (leitura.efeito) {
      case EfeitoRespostaPedido.sucesso:
        await _concluirEnvio(leitura.posicao);
      case EfeitoRespostaPedido.esvaziar:
        await _aviso(leitura.texto);
        if (!mounted) return;
        await _esvaziarEVoltar();
      case EfeitoRespostaPedido.manter:
        final texto = leitura.texto.trim();
        await _aviso(texto.isEmpty ? msgFalhaEnvio : texto);
    }
  }

  Future<void> _concluirEnvio(int? posicao) async {
    final session = ref.read(appSessionProvider.notifier);
    if (posicao != null) session.definirPosicao(posicao);
    final gravacao = session.limparCarrinho();
    if (!mounted) {
      await gravacao;
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_textoSucesso(posicao))),
    );
    _voltarCardapio();
    await gravacao;
  }

  Future<void> _esvaziarEVoltar() {
    final gravacao = ref.read(appSessionProvider.notifier).limparCarrinho();
    _voltarCardapio();
    return gravacao;
  }

  Future<void> _expirou() async {
    if (!mounted) return;
    await encerrarSessaoExpirada(context, ref);
  }

  void _pararEnvio() {
    if (mounted && _enviando) setState(() => _enviando = false);
  }

  void _voltarCardapio() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/cardapio');
  }

  Future<bool> _simNao(String mensagem) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    return resposta ?? false;
  }

  Future<void> _aviso(String mensagem) {
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final config = ref.watch(appConfigProvider);
    final carrinho = session.carrinho;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    title: const Text(
                      'Pedido',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    leading: IconButton(
                      onPressed: _voltarCardapio,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                    ),
                  ),
                  if (carrinho.isEmpty)
                    Expanded(
                      child: _PedidoVazio(onVerCardapio: _voltarCardapio),
                    )
                  else ...[
                    Expanded(
                      child: ListView.separated(
                        itemCount: carrinho.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFEDEDED),
                        ),
                        itemBuilder: (context, index) {
                          return _LinhaPedido(
                            linha: carrinho[index],
                            indice: index,
                            config: config,
                            pagina: ref.watch(paginaAbertaProvider),
                            onMenos: () => _mudarQuantidade(index, -1),
                            onMais: () => _mudarQuantidade(index, 1),
                          );
                        },
                      ),
                    ),
                    _RodapePedido(
                      total: somarCarrinho(carrinho),
                      enviando: _enviando,
                      onLimpar: _limpar,
                      onEnviar: _enviar,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

MesaHPedido _mesa(AppSessionState session) {
  return MesaHPedido(
    setor: session.local,
    numMesa: session.mesa,
    codLocal: session.local,
    posicao: session.posicao,
    socio: session.titulo,
    idPessoa: session.idSocio == 0 ? '0' : session.idSocio.toString(),
  );
}

String _textoSucesso(int? posicao) {
  if (posicao == null) return 'Pedido enviado';
  return 'Pedido enviado · posição $posicao';
}

String textoObservacoes(List<String> observacoes) {
  return [
    for (final item in observacoes)
      if (item.trim().isNotEmpty) item,
  ].join(' · ');
}

class _LinhaPedido extends StatelessWidget {
  final CartLine linha;
  final int indice;
  final AppConfig config;
  final Uri pagina;
  final VoidCallback onMenos;
  final VoidCallback onMais;

  const _LinhaPedido({
    required this.linha,
    required this.indice,
    required this.config,
    required this.pagina,
    required this.onMenos,
    required this.onMais,
  });

  @override
  Widget build(BuildContext context) {
    final obs = textoObservacoes(linha.observacoes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FotoProduto(
              codigo: linha.codigo,
              extensao: config.extProd,
              urlRede: config.urlFoto(linha.codigo, pagina: pagina),
              altura: 72,
              largura: 72,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        linha.descricao,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatMoney(linha.total),
                      key: Key('preco-linha-$indice'),
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (obs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    obs,
                    style: const TextStyle(
                      color: Color(0xFF6B6B6B),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Passo(
                      chave: Key('quantidade-menos-$indice'),
                      icone: Icons.remove,
                      onTap: onMenos,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        textoQuantidade(linha.quantidade),
                        key: Key('qtd-$indice'),
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _Passo(
                      chave: Key('quantidade-mais-$indice'),
                      icone: Icons.add,
                      onTap: onMais,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final Key chave;
  final IconData icone;
  final VoidCallback onTap;

  const _Passo({
    required this.chave,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final claro = corLegivelNoFundo(cor, Colors.white);
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: cor,
        borderRadius: bordaBotao,
        child: InkWell(
          key: chave,
          customBorder: formatoBotao(),
          onTap: onTap,
          child: Icon(icone, color: claro),
        ),
      ),
    );
  }
}

class _RodapePedido extends StatelessWidget {
  final double total;
  final bool enviando;
  final VoidCallback onLimpar;
  final VoidCallback onEnviar;

  const _RodapePedido({
    required this.total,
    required this.enviando,
    required this.onLimpar,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(cor, Colors.white);
    return Material(
      color: Colors.white,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                TextButton(
                  key: const Key('limpar-pedido'),
                  onPressed: enviando ? null : onLimpar,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: const Color(0xFF6B6B6B),
                  ),
                  child: const Text('Limpar'),
                ),
                const Spacer(),
                Text(
                  formatMoney(total),
                  key: const Key('total-pedido'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  key: const Key('enviar-pedido'),
                  onPressed: enviando ? null : onEnviar,
                  style: FilledButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: texto,
                    disabledBackgroundColor: cor,
                    disabledForegroundColor: texto,
                    shape: formatoBotao(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: enviando
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: texto,
                          ),
                        )
                      : const Text('Enviar pedido'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PedidoVazio extends StatelessWidget {
  final VoidCallback onVerCardapio;

  const _PedidoVazio({required this.onVerCardapio});

  @override
  Widget build(BuildContext context) {
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(cor, Colors.white);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 56,
              color: Color(0xFF6B6B6B),
            ),
            const SizedBox(height: 12),
            const Text(
              'Seu pedido está vazio',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('ver-cardapio'),
                onPressed: onVerCardapio,
                style: FilledButton.styleFrom(
                  backgroundColor: cor,
                  foregroundColor: texto,
                  shape: formatoBotao(),
                  minimumSize: const Size(44, 48),
                ),
                child: const Text('Ver cardápio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
