import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/acesso/acesso_regras.dart';
import '../../core/config/app_config.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/club_theme.dart';
import '../../core/web/pagina_aberta.dart';
import '../conta/pagar_mesa.dart';

class AcessoPage extends ConsumerStatefulWidget {
  const AcessoPage({super.key});

  @override
  ConsumerState<AcessoPage> createState() => _AcessoPageState();
}

class _AcessoPageState extends ConsumerState<AcessoPage> {
  final _titulo = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _semConexao = false;
  bool _formularioHabilitado = false;
  bool _acessando = false;
  String? _erroTitulo;
  String? _erroSenha;
  String? _erroRede;

  @override
  void initState() {
    super.initState();
    final session = ref.read(appSessionProvider);
    _titulo.text = session.titulo;
    if (session.mesa != 0 && session.local != 0) {
      _carregando = true;
      Future.microtask(_carregarClube);
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final semMesa = session.mesa == 0 || session.local == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CapaAcesso(tema: session.tema),
                          if (semMesa)
                            const _AvisoQr()
                          else if (_carregando)
                            const _SkeletonAcesso()
                          else if (_semConexao)
                            _RedeIndisponivel(onRepetir: _carregarClube)
                          else ...[
                            _CabecalhoAcesso(session: session),
                            _FormularioAcesso(
                              titulo: _titulo,
                              senha: _senha,
                              erroTitulo: _erroTitulo,
                              erroSenha: _erroSenha,
                              erroRede: _erroRede,
                              habilitado: _formularioHabilitado,
                              acessando: _acessando,
                              onAcessar: _acessar,
                              onRepetir: _acessar,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _carregarClube() async {
    final session = ref.read(appSessionProvider);
    if (session.mesa == 0 || session.local == 0) return;
    setState(() {
      _carregando = true;
      _semConexao = false;
      _formularioHabilitado = false;
    });
    final api = ref.read(cardapioApiProvider);
    final config = ref.read(appConfigProvider);
    try {
      final respostas = await Future.wait([
        api.parametros(session.local),
        api.setor(session.local),
      ]);
      if (!mounted) return;
      final bloqueio = bloqueioCarga(
        corpoParametros: respostas[0].corpoBruto,
        corpoSetor: respostas[1].corpoBruto,
      );
      final clube = lerClube(respostas[0].dados);
      ref.read(appSessionProvider.notifier).aplicarClube(
            tema: temaDoClube(
              clube.parametros,
              baseImagens: config.baseImagens,
              pagina: ref.read(paginaAbertaProvider),
            ),
            taxa: clube.taxa,
            habilitaPosicao: clube.habilitaPosicao,
            nomePosicao: clube.nomePosicao,
            descricaoSetor: lerDescricaoSetor(respostas[1].dados),
          );
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _formularioHabilitado = bloqueio == null;
      });
      if (bloqueio != null) await _aviso(bloqueio);
    } on CardapioApiException {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _semConexao = true;
        _formularioHabilitado = false;
      });
    }
  }

  Future<void> _acessar() async {
    if (_acessando || !_formularioHabilitado) return;
    final titulo = _titulo.text.trim();
    final senha = _senha.text;
    final session = ref.read(appSessionProvider);
    final config = ref.read(appConfigProvider);
    final porta = portaAcesso(titulo: titulo);
    setState(() {
      _erroTitulo = porta.acao == PortaAcao.tituloVazio ? porta.mensagem : null;
      _erroSenha = null;
      _erroRede = null;
    });
    if (porta.acao == PortaAcao.tituloVazio) return;

    setState(() => _acessando = true);
    try {
      await ref.read(appSessionProvider.notifier).definirTitulo(titulo);
      final api = ref.read(cardapioApiProvider);
      final modo =
          modoPosicaoMesa(session.habilitaPosicao, session.nomePosicao);
      final resposta = modo
          ? await api.statusMesaPosicao(session.mesa, session.local, titulo)
          : await api.statusMesa(
              session.mesa,
              session.local,
              session.posicao,
              titulo,
            );
      if (!mounted) return;
      final status = interpretarStatus(
        corpo: resposta.corpoBruto,
        modoPosicao: modo,
        titulo: titulo,
        posicaoAtual: session.posicao,
      );
      if (status.invalido) {
        await _aviso(status.mensagem);
        return;
      }
      if (status.gravarPosicao) {
        ref.read(appSessionProvider.notifier).definirPosicao(status.posicao);
      }
      final trava = classificarMesa(
        fechaConta: status.fechaConta,
        referenciaStatus: status.referenciaStatus,
        mesaQr: session.mesa,
      );
      if (trava == TravaMesa.fechada) {
        await _aviso(msgMesaFechada);
        return;
      }
      if (trava == TravaMesa.anterior) {
        final seguiu = await _mesaAnterior(
          api: api,
          titulo: titulo,
          senha: senha,
          session: session,
          referenciaStatus: status.referenciaStatus,
        );
        if (!seguiu) return;
      }
      await _entrarComSenha(
        api: api,
        titulo: titulo,
        senha: senha,
        semSenha: config.semSenha,
      );
    } on CardapioApiException catch (error) {
      if (!mounted) return;
      setState(() => _erroRede = error.message);
    } finally {
      if (mounted) setState(() => _acessando = false);
    }
  }

  Future<bool> _mesaAnterior({
    required CardapioApi api,
    required String titulo,
    required String senha,
    required AppSessionState session,
    required String referenciaStatus,
  }) async {
    final posicao = ref.read(appSessionProvider).posicao;
    final cabecalho = await api.mesaH(
      session.mesa,
      session.local,
      posicao,
      titulo,
    );
    if (!mounted) return false;
    final decisao = decidirMesaAnterior(
      corpo: cabecalho.corpoBruto,
      titulo: titulo,
      mesa: session.mesa,
      posicao: posicao,
      referenciaStatus: referenciaStatus,
      taxa: ref.read(appSessionProvider).taxa,
    );
    if (decisao.acao == AcaoMesaAnterior.seguir) return true;
    if (decisao.acao == AcaoMesaAnterior.pagar) {
      final sim = await _simNao(decisao.mensagem);
      if (sim && mounted) {
        final fim = await pagarMesaAtual(
          context,
          ref,
          valor: decisao.total,
          senha: senha,
        );
        if (fim == FimPagamento.senhaVazia && mounted) {
          setState(() => _erroSenha = msgDigiteSenha);
        }
      }
      return false;
    }
    await _aviso(decisao.mensagem);
    return false;
  }

  Future<void> _entrarComSenha({
    required CardapioApi api,
    required String titulo,
    required String senha,
    required String semSenha,
  }) async {
    final passo = passoSenha(senha: senha, semSenha: semSenha);
    if (passo == PassoSenha.pedirSenha) {
      setState(() => _erroSenha = msgDigiteSenha);
      return;
    }
    final cliente = await api.cliente(titulo);
    if (!mounted) return;
    final trava = decidirCliente(cliente.corpoBruto);
    if (trava.trava == ClienteTrava.naoEncontrado) {
      _titulo.clear();
      _senha.clear();
      setState(() => _erroTitulo = trava.mensagem);
      return;
    }
    if (trava.trava == ClienteTrava.indisponivel) {
      setState(() => _erroTitulo = trava.mensagem);
      return;
    }
    if (passo == PassoSenha.semSenha) {
      _concluir(trava.nome, trava.idSocio);
      return;
    }
    final senhaResp = await api.clienteSenha(titulo, senha);
    if (!mounted) return;
    final resultado = decidirSenha(senhaResp.corpoBruto);
    if (resultado.acao == AcaoSenha.invalida) {
      _senha.clear();
      setState(() => _erroSenha = resultado.mensagem);
      return;
    }
    if (resultado.acao == AcaoSenha.texto) {
      await _aviso(resultado.mensagem);
      return;
    }
    _concluir(trava.nome, resultado.idSocio);
  }

  Future<void> _concluir(String nome, int idSocio) async {
    final session = ref.read(appSessionProvider.notifier);
    await session.entrar(nome: nome, idSocio: idSocio);
    await session.renovarEntrada();
    if (!mounted) return;
    context.go('/cardapio');
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

class FundoClube extends StatefulWidget {
  final ClubTheme tema;
  final Widget child;

  const FundoClube({super.key, required this.tema, required this.child});

  @override
  State<FundoClube> createState() => _FundoClubeState();
}

class _FundoClubeState extends State<FundoClube> {
  bool _imagemFalhou = false;

  @override
  void didUpdateWidget(FundoClube oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tema.fundoUrl != widget.tema.fundoUrl) {
      _imagemFalhou = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = widget.tema;
    final gradient = tema.background;
    final mostraImagem = tema.fundoUrl != null && !_imagemFalhou;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? tema.primary : null,
        gradient: gradient,
        image: mostraImagem
            ? DecorationImage(
                image: NetworkImage(tema.fundoUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_imagemFalhou) {
                      setState(() => _imagemFalhou = true);
                    }
                  });
                },
              )
            : null,
      ),
      child: widget.child,
    );
  }
}

class _CapaAcesso extends StatelessWidget {
  final ClubTheme tema;

  const _CapaAcesso({required this.tema});

  @override
  Widget build(BuildContext context) {
    final primaria = tema.primary;
    final topo = Color.alphaBlend(const Color(0xA6F6F1F1), primaria);
    final meio = Color.alphaBlend(const Color(0xD4FFFFFF), primaria);
    final temFoto = tema.fundoUrl != null;
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (temFoto) FundoClube(tema: tema, child: const SizedBox.expand()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: temFoto
                      ? const [
                          Color(0x73F4EEEE),
                          Color(0xD0FFFFFF),
                          Color(0xF7FFFFFF),
                        ]
                      : [topo, meio, const Color(0xFFF6F3F3)],
                  stops: const [0, 0.58, 1],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SizedBox(height: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoAcesso extends StatelessWidget {
  final AppSessionState session;

  const _CabecalhoAcesso({required this.session});

  @override
  Widget build(BuildContext context) {
    final tema = session.tema;
    final nome = session.descricaoSetor.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MarcaClube(tema: tema, nome: nome),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nome.isNotEmpty)
                  Text(
                    nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EtiquetaMesa(texto: 'Mesa ${session.mesa}'),
                    if (session.posicao != 0)
                      _EtiquetaMesa(texto: 'Posição ${session.posicao}'),
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

class _MarcaClube extends StatelessWidget {
  final ClubTheme tema;
  final String nome;

  const _MarcaClube({required this.tema, required this.nome});

  @override
  Widget build(BuildContext context) {
    final letra = nome.isEmpty ? 'S' : nome.characters.first.toUpperCase();
    return Container(
      width: 56,
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            _LetraMarca(letra: letra, cor: tema.primary),
      ),
    );
  }
}

class _LetraMarca extends StatelessWidget {
  final String letra;
  final Color cor;

  const _LetraMarca({required this.letra, required this.cor});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cor,
      child: Center(
        child: Text(
          letra,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EtiquetaMesa extends StatelessWidget {
  final String texto;

  const _EtiquetaMesa({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AvisoQr extends StatelessWidget {
  const _AvisoQr();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 56, color: Color(0xFF222222)),
          SizedBox(height: 16),
          Text(
            'Leia o QR Code da mesa',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Aponte a câmera para o código da mesa para abrir o cardápio.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Color(0xFF6B6B6B), fontSize: 15, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _FormularioAcesso extends StatelessWidget {
  final TextEditingController titulo;
  final TextEditingController senha;
  final String? erroTitulo;
  final String? erroSenha;
  final String? erroRede;
  final bool habilitado;
  final bool acessando;
  final VoidCallback onAcessar;
  final VoidCallback onRepetir;

  const _FormularioAcesso({
    required this.titulo,
    required this.senha,
    required this.erroTitulo,
    required this.erroSenha,
    required this.erroRede,
    required this.habilitado,
    required this.acessando,
    required this.onAcessar,
    required this.onRepetir,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final primaria = tema.colorScheme.primary;
    final fundoBotao = corBotao(primaria);
    final textoBotao =
        corLegivelNoFundo(fundoBotao, tema.colorScheme.onPrimary);
    final podeEditar = habilitado && !acessando;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Informe o título do sócio',
            style: TextStyle(
              color: Color(0xFF6B6B6B),
              fontSize: 15,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('campo-titulo'),
            controller: titulo,
            enabled: podeEditar,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
            decoration:
                _campo('Título', erroTitulo, Icons.badge_outlined, primaria),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo-senha'),
            controller: senha,
            enabled: podeEditar,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAcessar(),
            style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
            decoration:
                _campo('Senha', erroSenha, Icons.lock_outline, primaria),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: podeEditar ? onAcessar : null,
              style: FilledButton.styleFrom(
                backgroundColor: fundoBotao,
                foregroundColor: textoBotao,
                disabledBackgroundColor: fundoBotao.withValues(alpha: 0.4),
                disabledForegroundColor: textoBotao,
                shape: formatoBotao(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: acessando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textoBotao,
                      ),
                    )
                  : const Text('Acessar'),
            ),
          ),
          if (erroRede != null) ...[
            const SizedBox(height: 12),
            Text(
              erroRede!,
              style: TextStyle(color: tema.colorScheme.error),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRepetir,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: const Text('Repetir'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _campo(
    String label,
    String? erro,
    IconData icone,
    Color primaria,
  ) {
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      labelText: label,
      errorText: erro,
      errorMaxLines: 4,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      prefixIcon: Icon(icone, color: const Color(0xFF6B6B6B)),
      border: borda,
      enabledBorder: borda,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaria, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }
}

class _RedeIndisponivel extends StatelessWidget {
  final VoidCallback onRepetir;

  const _RedeIndisponivel({required this.onRepetir});

  @override
  Widget build(BuildContext context) {
    final fundo = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(fundo, Colors.white);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, size: 40, color: Color(0xFF6B6B6B)),
          const SizedBox(height: 12),
          const Text(
            'Sem conexão. Tente de novo.',
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
              onPressed: onRepetir,
              style: FilledButton.styleFrom(
                backgroundColor: fundo,
                foregroundColor: texto,
                shape: formatoBotao(),
                minimumSize: const Size(44, 48),
              ),
              child: const Text('Repetir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonAcesso extends StatelessWidget {
  const _SkeletonAcesso();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _BarraSkeleton(width: 56, height: 88),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BarraSkeleton(width: 160, height: 22),
                    SizedBox(height: 10),
                    _BarraSkeleton(width: 88, height: 26),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          _BarraSkeleton(width: double.infinity, height: 56),
          SizedBox(height: 12),
          _BarraSkeleton(width: double.infinity, height: 56),
          SizedBox(height: 20),
          _BarraSkeleton(width: double.infinity, height: 52),
        ],
      ),
    );
  }
}

class _BarraSkeleton extends StatelessWidget {
  final double width;
  final double height;

  const _BarraSkeleton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
