import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/acesso/acesso_regras.dart';
import '../../core/config/app_config.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/session/app_session.dart';
import '../../core/session/sessao_guarda.dart';
import '../../core/web/pagina_aberta.dart';
import '../../core/theme/club_theme.dart';
import '../../shared/models/conta.dart';
import '../cardapio/cardapio_regras.dart';
import '../cardapio/foto_produto.dart';
import 'conta_regras.dart';

class ContaPage extends ConsumerStatefulWidget {
  const ContaPage({super.key});

  @override
  ConsumerState<ContaPage> createState() => _ContaPageState();
}

class _ContaPageState extends ConsumerState<ContaPage> {
  bool _carregando = true;
  bool _erroRede = false;
  bool _fechada = false;
  ItensMesa _lista = const ItensMesa(itens: []);

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
  }

  Future<void> _carregar() async {
    if (sessaoAtualExpirada(ref)) {
      if (mounted) setState(() => _carregando = false);
      await encerrarSessaoExpirada(context, ref);
      return;
    }
    final session = ref.read(appSessionProvider);
    setState(() {
      _carregando = true;
      _erroRede = false;
    });
    final api = ref.read(cardapioApiProvider);
    final modo = modoPosicaoMesa(session.habilitaPosicao, session.nomePosicao);
    try {
      final itens = await api.mesaI(
        session.mesa,
        session.local,
        session.posicao,
        session.titulo,
      );
      final status = modo
          ? await api.statusMesaPosicao(
              session.mesa,
              session.local,
              session.titulo,
            )
          : await api.statusMesa(
              session.mesa,
              session.local,
              session.posicao,
              session.titulo,
            );
      if (!mounted) return;
      final lidos = interpretarStatus(
        corpo: status.corpoBruto,
        modoPosicao: modo,
        titulo: session.titulo,
        posicaoAtual: session.posicao,
      );
      setState(() {
        _carregando = false;
        _lista = lerItensMesa(itens.corpoBruto, itens.dados);
        _fechada = !lidos.invalido &&
            faixaMesaFechada(
              fechaConta: lidos.fechaConta,
              referenciaStatus: lidos.referenciaStatus,
              mesa: session.mesa,
            );
      });
    } on CardapioApiException {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroRede = true;
      });
    }
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/cardapio');
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return _Moldura(
      titulo: 'Conta',
      onVoltar: _voltar,
      child: _corpo(config),
    );
  }

  Widget _corpo(AppConfig config) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erroRede) {
      return _Rede(onRepetir: _carregar);
    }
    final soma = somarItensConta(_lista.itens);
    return Column(
      children: [
        Expanded(child: _miolo(config)),
        _RodapeConta(
          fechada: _fechada,
          rodape: _lista.itens.isEmpty ? null : rodapeConta(soma),
          onPagar: () => context.push('/conta/pagamento'),
        ),
      ],
    );
  }

  Widget _miolo(AppConfig config) {
    if (_lista.itens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _lista.mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _lista.itens.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEDEDED)),
      itemBuilder: (context, index) {
        return _LinhaConta(
          item: _lista.itens[index],
          indice: index,
          config: config,
          pagina: ref.watch(paginaAbertaProvider),
        );
      },
    );
  }
}

class _LinhaConta extends StatelessWidget {
  final ContaItem item;
  final int indice;
  final AppConfig config;
  final Uri pagina;

  const _LinhaConta({
    required this.item,
    required this.indice,
    required this.config,
    required this.pagina,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FotoProduto(
              codigo: item.produto,
              extensao: config.extProd,
              urlRede: config.urlFoto(item.produto, pagina: pagina),
              altura: 72,
              largura: 72,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.descricao,
                  key: Key('desc-conta-$indice'),
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textoQuantidade(item.quantidade),
                  key: Key('qtd-conta-$indice'),
                  style: const TextStyle(
                    color: Color(0xFF6B6B6B),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            reaisNaTela(item.valor),
            key: Key('valor-conta-$indice'),
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RodapeConta extends StatelessWidget {
  final bool fechada;
  final String? rodape;
  final VoidCallback onPagar;

  const _RodapeConta({
    required this.fechada,
    required this.rodape,
    required this.onPagar,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (fechada) ...[
              Container(
                key: const Key('faixa-mesa-fechada'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: const Color(0xFFFFF4E5),
                child: const Text(
                  msgFaixaMesaFechada,
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (rodape != null) ...[
              Text(
                rodape!,
                key: const Key('rodape-conta'),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('ir-pagamento'),
                onPressed: fechada ? null : onPagar,
                style: FilledButton.styleFrom(
                  backgroundColor: cor,
                  foregroundColor: texto,
                  disabledBackgroundColor: cor.withValues(alpha: 0.4),
                  disabledForegroundColor: texto,
                  shape: formatoBotao(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Ir para pagamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rede extends StatelessWidget {
  final VoidCallback onRepetir;

  const _Rede({required this.onRepetir});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CardapioApi.mensagemRede,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRepetir,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Repetir'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Moldura extends StatelessWidget {
  final String titulo;
  final VoidCallback onVoltar;
  final Widget child;

  const _Moldura({
    required this.titulo,
    required this.onVoltar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Colors.white,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    title: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    leading: IconButton(
                      onPressed: onVoltar,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
