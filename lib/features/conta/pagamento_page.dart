import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/acesso/acesso_regras.dart';
import '../../core/config/app_config.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/session/app_session.dart';
import '../../core/session/sessao_guarda.dart';
import '../../core/theme/club_theme.dart';
import 'conta_regras.dart';
import 'pagar_mesa.dart';

class PagamentoPage extends ConsumerStatefulWidget {
  const PagamentoPage({super.key});

  @override
  ConsumerState<PagamentoPage> createState() => _PagamentoPageState();
}

class _PagamentoPageState extends ConsumerState<PagamentoPage> {
  final _senha = TextEditingController();
  bool _carregando = true;
  bool _erroRede = false;
  bool _senhaVisivel = false;
  bool _ocupado = false;
  bool _enviando = false;
  String? _erroSenha;
  String? _aviso;
  CabecalhoMesa _cabecalho = const CabecalhoMesa();

  @override
  void initState() {
    super.initState();
    Future.microtask(_carregar);
  }

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
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
      _aviso = null;
    });
    try {
      final resposta = await ref.read(cardapioApiProvider).mesaH(
            session.mesa,
            session.local,
            session.posicao,
            session.titulo,
          );
      if (!mounted) return;
      final cabecalho = lerCabecalhoMesa(resposta.corpoBruto, resposta.dados);
      setState(() {
        _carregando = false;
        _cabecalho = cabecalho;
        _aviso = cabecalho.ok ? null : cabecalho.mensagem;
      });
    } on CardapioApiException {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erroRede = true;
      });
    }
  }

  Future<void> _pagar() async {
    if (_ocupado) return;
    final conta = _cabecalho.conta;
    if (conta == null) return;
    final config = ref.read(appConfigProvider);
    final passo = passoConfirmar(
      semSenha: config.semSenha,
      senhaVisivel: _senhaVisivel,
      senha: _senha.text,
    );
    if (passo == PassoConfirmar.revelarSenha) {
      setState(() {
        _senhaVisivel = true;
        _erroSenha = null;
      });
      return;
    }
    if (passo == PassoConfirmar.senhaVazia) {
      setState(() => _erroSenha = msgDigiteSenha);
      return;
    }

    if (sessaoAtualExpirada(ref)) {
      await encerrarSessaoExpirada(context, ref);
      return;
    }

    final total = valorPagamento(
      conta.valorConsumido,
      ref.read(appSessionProvider).taxa,
    );
    _ocupado = true;
    setState(() => _erroSenha = null);
    final sim = await _simNao(perguntaPagamento(total));
    if (!sim || !mounted) {
      _ocupado = false;
      if (mounted) setState(() {});
      return;
    }
    setState(() => _enviando = true);
    final fim = await pagarMesaAtual(
      context,
      ref,
      valor: total,
      senha: _senha.text,
    );
    if (!mounted) return;
    _ocupado = false;
    setState(() {
      _enviando = false;
      if (fim == FimPagamento.senhaVazia) _erroSenha = msgDigiteSenha;
    });
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/conta');
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final conta = _cabecalho.conta;
    final total = conta == null
        ? 0.0
        : valorPagamento(conta.valorConsumido, session.taxa);
    return _Moldura(
      titulo: 'Pagamento',
      onVoltar: _voltar,
      child: _corpo(session, total),
    );
  }

  Widget _corpo(AppSessionState session, double total) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erroRede) return _Rede(onRepetir: _carregar);
    final conta = _cabecalho.conta;
    if (conta == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _aviso ?? '',
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
    final taxaValor = valorDaTaxa(conta.valorConsumido, session.taxa);
    final linhas = [
      _Par('Mesa', '${session.mesa}', const Key('valor-mesa')),
      _Par(
        'Abertura',
        formatarAbertura(conta.abertura),
        const Key('valor-abertura'),
      ),
      _Par('Atendente', conta.atendente, const Key('valor-atendente')),
      _Par('Título', session.titulo, const Key('valor-titulo')),
      _Par('Nome', session.nomeSocio, const Key('valor-nome')),
      _Par(
        'Total consumido',
        reaisNaTela(conta.valorConsumido),
        const Key('valor-consumido'),
      ),
      _Par(
        rotuloTaxa(session.taxa),
        reaisNaTela(taxaValor),
        const Key('valor-taxa'),
      ),
      _Par('Total', reaisNaTela(total), const Key('valor-total')),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (final linha in linhas) ...[
                _LinhaValor(par: linha),
                const Divider(height: 1, color: Color(0xFFEDEDED)),
              ],
            ],
          ),
        ),
        _RodapePagar(
          rotulo: _senhaVisivel ? 'Confirmar pagamento' : rotuloPagar(total),
          enviando: _enviando,
          ocupado: _ocupado,
          senha: _senhaVisivel ? _senha : null,
          erroSenha: _erroSenha,
          onPagar: _pagar,
        ),
      ],
    );
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
}

class _Par {
  final String rotulo;
  final String valor;
  final Key chave;

  const _Par(this.rotulo, this.valor, this.chave);
}

class _LinhaValor extends StatelessWidget {
  final _Par par;

  const _LinhaValor({required this.par});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              par.rotulo,
              style: const TextStyle(
                color: Color(0xFF6B6B6B),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              par.valor,
              key: par.chave,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RodapePagar extends StatelessWidget {
  final String rotulo;
  final bool enviando;
  final bool ocupado;
  final TextEditingController? senha;
  final String? erroSenha;
  final VoidCallback onPagar;

  const _RodapePagar({
    required this.rotulo,
    required this.enviando,
    required this.ocupado,
    required this.senha,
    required this.erroSenha,
    required this.onPagar,
  });

  @override
  Widget build(BuildContext context) {
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(
      cor,
      Theme.of(context).colorScheme.onPrimary,
    );
    final campo = senha;
    final bloqueado = enviando || ocupado;
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
            if (campo != null) ...[
              TextField(
                key: const Key('campo-senha-pagamento'),
                controller: campo,
                enabled: !enviando,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onPagar(),
                style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  errorText: erroSenha,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                key: const Key('botao-pagar'),
                onPressed: bloqueado ? null : onPagar,
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
                    : Text(rotulo),
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
