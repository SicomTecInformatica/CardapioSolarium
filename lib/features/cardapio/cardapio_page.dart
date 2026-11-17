import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/format/money.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/relogio.dart';
import '../../core/session/app_session.dart';
import '../../core/session/sessao_guarda.dart';
import '../../core/web/pagina_aberta.dart';
import '../../core/theme/club_theme.dart';
import '../../shared/models/cart_line.dart';
import '../../shared/models/grupo.dart';
import '../../shared/models/produto.dart';
import '../conta/conta_regras.dart';
import 'cardapio_cache.dart';
import 'cardapio_regras.dart';
import 'foto_produto.dart';
import 'produto_regras.dart';
import 'produto_sheet.dart';

class CardapioPage extends ConsumerStatefulWidget {
  const CardapioPage({super.key});

  @override
  ConsumerState<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends ConsumerState<CardapioPage> {
  final _busca = TextEditingController();
  final _scroll = ScrollController();
  final _listaKey = GlobalKey();
  final _chaves = <GlobalKey>[];
  List<SecaoCardapio> _secoes = const [];
  bool _carregando = true;
  bool _semRede = false;
  int _chip = 0;
  final _repetindo = <int>{};
  bool _avisoExpirado = false;
  bool _marcacaoAgendada = false;
  bool _rolandoParaChip = false;
  int _quantidadeConta = 0;

  static const _alturaComChips = 124.0;
  static const _alturaSemChips = 72.0;

  @override
  void initState() {
    super.initState();
    _busca.addListener(() {
      if (mounted) setState(() {});
    });
    _scroll.addListener(_aoRolar);
    Future.microtask(_carregar);
    Future.microtask(_lerQuantidadeConta);
  }

  @override
  void dispose() {
    _busca.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _buscando => _busca.text.trim().isNotEmpty;

  bool _mostrarChips(List<SecaoCardapio> visiveis) =>
      !_buscando && visiveis.isNotEmpty;

  double _alturaDe(bool chips) => chips ? _alturaComChips : _alturaSemChips;

  Future<void> _lerQuantidadeConta() async {
    if (sessaoAtualExpirada(ref)) return;
    final session = ref.read(appSessionProvider);
    try {
      final resposta = await ref.read(cardapioApiProvider).mesaI(
            session.mesa,
            session.local,
            session.posicao,
            session.titulo,
          );
      if (!mounted) return;
      final itens = lerItensMesa(resposta.corpoBruto, resposta.dados);
      final total = somarItensConta(itens.itens).quantidade.round();
      setState(() => _quantidadeConta = total);
    } on CardapioApiException {
      if (!mounted) return;
    }
  }

  Future<void> _abrirConta() async {
    await context.push('/conta');
    if (mounted) await _lerQuantidadeConta();
  }

  Future<void> _abrirPedido() async {
    await context.push('/pedido');
    if (mounted) await _lerQuantidadeConta();
  }

  Future<void> _carregar({bool forcar = false}) async {
    final session = ref.read(appSessionProvider);
    final agora = ref.read(relogioProvider)();
    if (sessaoAtualExpirada(ref)) {
      await _expirou();
      return;
    }

    final cache = ref.read(cacheCardapioProvider.notifier);
    if (!forcar && cache.gruposFrescos(session.local, agora)) {
      final guardados = ref.read(cacheCardapioProvider);
      final secoes = await _produtosDosGrupos(
        guardados.grupos,
        local: session.local,
        agora: agora,
        forcar: false,
      );
      if (!mounted) return;
      setState(() {
        _aplicar(secoes);
        _carregando = false;
        _semRede = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _semRede = false;
    });
    try {
      final resposta =
          await ref.read(cardapioApiProvider).grupos(session.local);
      final grupos = lerGrupos(resposta.dados, resposta.corpoBruto);
      cache.guardarGrupos(session.local, grupos, agora);
      final secoes = await _produtosDosGrupos(
        grupos,
        local: session.local,
        agora: agora,
        forcar: forcar,
      );
      if (!mounted) return;
      setState(() {
        _aplicar(secoes);
        _carregando = false;
        _semRede = false;
      });
    } on CardapioApiException {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _semRede = true;
      });
    }
  }

  Future<List<SecaoCardapio>> _produtosDosGrupos(
    List<Grupo> grupos, {
    required int local,
    required DateTime agora,
    required bool forcar,
  }) {
    return emFila([
      for (final grupo in grupos)
        () => _buscarGrupo(
              grupo,
              local: local,
              agora: agora,
              forcar: forcar,
            ),
    ]);
  }

  Future<SecaoCardapio> _buscarGrupo(
    Grupo grupo, {
    required int local,
    required DateTime agora,
    required bool forcar,
  }) async {
    final cache = ref.read(cacheCardapioProvider.notifier);
    final fresco = cache.produtosFrescos(local, grupo.codigoGrupo, agora);
    if (!forcar && fresco != null) {
      return SecaoCardapio(
        codigoGrupo: grupo.codigoGrupo,
        descricaoGrupo: grupo.descricaoGrupo,
        produtos: fresco.produtos,
        falhou: false,
      );
    }
    try {
      final resposta = await ref
          .read(cardapioApiProvider)
          .produtos(grupo.codigoGrupo, local);
      final produtos = lerProdutos(resposta.dados, resposta.corpoBruto);
      cache.guardarProdutos(
        local: local,
        codigoGrupo: grupo.codigoGrupo,
        produtos: produtos,
        falhou: false,
        em: agora,
      );
      return SecaoCardapio(
        codigoGrupo: grupo.codigoGrupo,
        descricaoGrupo: grupo.descricaoGrupo,
        produtos: produtos,
        falhou: false,
      );
    } on CardapioApiException {
      cache.guardarProdutos(
        local: local,
        codigoGrupo: grupo.codigoGrupo,
        produtos: const [],
        falhou: true,
        em: agora,
      );
      return SecaoCardapio(
        codigoGrupo: grupo.codigoGrupo,
        descricaoGrupo: grupo.descricaoGrupo,
        produtos: const [],
        falhou: true,
      );
    }
  }

  Future<void> _repetirGrupo(int indice) async {
    final secao = _secoes[indice];
    if (_repetindo.contains(secao.codigoGrupo)) return;
    setState(() => _repetindo.add(secao.codigoGrupo));
    final session = ref.read(appSessionProvider);
    final agora = ref.read(relogioProvider)();
    final nova = await _buscarGrupo(
      Grupo(
        codigoGrupo: secao.codigoGrupo,
        descricaoGrupo: secao.descricaoGrupo,
      ),
      local: session.local,
      agora: agora,
      forcar: true,
    );
    if (!mounted) return;
    setState(() {
      _repetindo.remove(secao.codigoGrupo);
      _secoes = [
        for (var i = 0; i < _secoes.length; i++)
          if (i == indice) nova else _secoes[i],
      ];
      _sincronizarChaves();
    });
  }

  void _aplicar(List<SecaoCardapio> secoes) {
    _secoes = secoes;
    _chip = 0;
    _sincronizarChaves();
  }

  void _sincronizarChaves() {
    final visiveis = secoesVisiveis(_secoes);
    while (_chaves.length < visiveis.length) {
      _chaves.add(GlobalKey());
    }
    if (_chaves.length > visiveis.length) {
      _chaves.removeRange(visiveis.length, _chaves.length);
    }
  }

  Future<void> _expirou() async {
    if (!mounted || _avisoExpirado) return;
    _avisoExpirado = true;
    setState(() => _carregando = false);
    await encerrarSessaoExpirada(context, ref);
  }

  Future<void> _abrir(Produto produto, int codigoGrupo) async {
    final incluiu = await abrirProduto(
      context,
      produto: produto,
      codigoGrupo: codigoGrupo,
    );
    if (!mounted || !incluiu) return;
    _avisar(msgAdicionadoPedido);
  }

  void _avisar(String texto) {
    final aviso = ScaffoldMessenger.of(context);
    aviso.removeCurrentSnackBar();
    aviso.showSnackBar(SnackBar(content: Text(texto)));
  }

  void _aoRolar() {
    if (_marcacaoAgendada) return;
    _marcacaoAgendada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _marcacaoAgendada = false;
      if (!mounted) return;
      _marcarSecaoVisivel();
    });
  }

  void _marcarSecaoVisivel() {
    if (_rolandoParaChip || _buscando || !_scroll.hasClients) return;
    final topos = _toposDasSecoes();
    final linha = _alturaDe(_mostrarChips(secoesVisiveis(_secoes))) + 4;
    final indice = secaoVisivel(topos, linha, atual: _chip);
    if (indice != _chip) setState(() => _chip = indice);
  }

  List<double> _toposDasSecoes() {
    final scrollBox =
        _listaKey.currentContext?.findRenderObject() as RenderBox?;
    if (scrollBox == null) return const [];
    return [
      for (final chave in _chaves.take(secoesVisiveis(_secoes).length))
        _topoDe(chave, scrollBox),
    ];
  }

  double _topoDe(GlobalKey chave, RenderBox scrollBox) {
    final box = chave.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return double.infinity;
    return box.localToGlobal(Offset.zero, ancestor: scrollBox).dy;
  }

  void _rolarPara(int indice) {
    if (!_scroll.hasClients) return;
    final chave = indice < _chaves.length ? _chaves[indice] : null;
    final box = chave?.currentContext?.findRenderObject();
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    // O alinhamento 0 já encosta o título logo abaixo da faixa fixa.
    final alvo = viewport
        .getOffsetToReveal(box, 0)
        .offset
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _rolandoParaChip = true;
    setState(() => _chip = indice);
    _scroll
        .animateTo(
          alvo,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
      if (!mounted) return;
      _rolandoParaChip = false;
      _marcarSecaoVisivel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider);
    final visiveis = secoesVisiveis(_secoes);
    final resultados =
        _buscando ? filtrarCardapio(_secoes, _busca.text) : const <ItemBusca>[];
    final mostrarChips = _mostrarChips(visiveis);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: Colors.white,
              child: Stack(
                children: [
                  Column(
                    children: [
                      _BarraTopo(
                        session: session,
                        quantidadeConta: _quantidadeConta,
                        onAbrirConta: _abrirConta,
                      ),
                      Expanded(
                        child:
                            _corpo(session, visiveis, resultados, mostrarChips),
                      ),
                    ],
                  ),
                  if (session.carrinho.isNotEmpty)
                    _BarraPedido(
                      carrinho: session.carrinho,
                      onAbrir: _abrirPedido,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _corpo(
    AppSessionState session,
    List<SecaoCardapio> visiveis,
    List<ItemBusca> resultados,
    bool mostrarChips,
  ) {
    if (_carregando) return const _SkeletonCardapio();
    if (_semRede) {
      return _ErroRede(onRepetir: () => _carregar(forcar: true));
    }
    final vazio = visiveis.isEmpty;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_rolandoParaChip &&
            notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _rolandoParaChip = false;
        }
        return false;
      },
      child: CustomScrollView(
        key: _listaKey,
        controller: _scroll,
        slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _CabecalhoFixo(
            altura: _alturaDe(mostrarChips),
            child: _BuscaEChips(
              busca: _busca,
              mostrarChips: mostrarChips,
              secoes: visiveis,
              selecionado: _chip,
              onChip: _rolarPara,
            ),
          ),
        ),
        if (vazio)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _MensagemCentro(msgCardapioVazio),
          )
        else if (_buscando && resultados.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _MensagemCentro(msgBuscaVazia),
          )
        else if (_buscando)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = resultados[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        item.categoria,
                        style: const TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _CardProduto(
                      produto: item.produto,
                      codigoGrupo: item.codigoGrupo,
                      onAbrir: () => _abrir(item.produto, item.codigoGrupo),
                    ),
                  ],
                );
              },
              childCount: resultados.length,
            ),
          )
        else ...[
          for (var i = 0; i < visiveis.length; i++) ..._secao(visiveis[i], i),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 88)),
      ],
      ),
    );
  }

  List<Widget> _secao(SecaoCardapio secao, int indice) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          key: _chaves[indice],
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(
            secao.descricaoGrupo,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      if (secao.falhou)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mensagemFalhaGrupo(secao.descricaoGrupo),
                  style:
                      const TextStyle(color: Color(0xFF222222), fontSize: 15),
                ),
                TextButton(
                  onPressed: _repetindo.contains(secao.codigoGrupo)
                      ? null
                      : () => _repetirGrupo(
                            _secoes.indexWhere(
                              (item) => item.codigoGrupo == secao.codigoGrupo,
                            ),
                          ),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  child: const Text('Repetir'),
                ),
              ],
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final produto = secao.produtos[index];
              return _CardProduto(
                produto: produto,
                codigoGrupo: secao.codigoGrupo,
                onAbrir: () => _abrir(produto, secao.codigoGrupo),
              );
            },
            childCount: secao.produtos.length,
          ),
        ),
    ];
  }
}

class _BarraTopo extends StatelessWidget {
  final AppSessionState session;
  final int quantidadeConta;
  final VoidCallback onAbrirConta;

  const _BarraTopo({
    required this.session,
    required this.quantidadeConta,
    required this.onAbrirConta,
  });

  @override
  Widget build(BuildContext context) {
    final mesa = 'Mesa ${session.mesa}';
    final subtitulo =
        session.posicao == 0 ? mesa : '$mesa · Posição ${session.posicao}';
    final nome = session.descricaoSetor.trim();
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 28, height: 40),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (nome.isNotEmpty)
                      Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    Text(
                      subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('abrir-conta'),
                tooltip: 'Conta',
                onPressed: onAbrirConta,
                color: const Color(0xFF1A1A1A),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 26),
                    if (quantidadeConta > 0)
                      Positioned(
                        left: -2,
                        bottom: -4,
                        child: _SeloItens(quantidade: quantidadeConta),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeloItens extends StatelessWidget {
  final int quantidade;

  const _SeloItens({required this.quantidade});

  @override
  Widget build(BuildContext context) {
    final rotulo = quantidade > 99 ? '99+' : '$quantidade';
    return Container(
      key: const Key('qtd-itens-pagamento'),
      width: rotulo.length > 1 ? null : 18,
      height: 18,
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: EdgeInsets.symmetric(horizontal: rotulo.length > 1 ? 4 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        shape: rotulo.length > 1 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: rotulo.length > 1 ? BorderRadius.circular(9) : null,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        rotulo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _CabecalhoFixo extends SliverPersistentHeaderDelegate {
  final double altura;
  final Widget child;

  _CabecalhoFixo({required this.altura, required this.child});

  @override
  double get minExtent => altura;

  @override
  double get maxExtent => altura;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(color: Colors.white, child: child);
  }

  @override
  bool shouldRebuild(_CabecalhoFixo oldDelegate) {
    return oldDelegate.altura != altura || oldDelegate.child != child;
  }
}

class _BuscaEChips extends StatefulWidget {
  final TextEditingController busca;
  final bool mostrarChips;
  final List<SecaoCardapio> secoes;
  final int selecionado;
  final ValueChanged<int> onChip;

  const _BuscaEChips({
    required this.busca,
    required this.mostrarChips,
    required this.secoes,
    required this.selecionado,
    required this.onChip,
  });

  @override
  State<_BuscaEChips> createState() => _BuscaEChipsState();
}

class _BuscaEChipsState extends State<_BuscaEChips> {
  final List<GlobalKey> _chaves = [];

  @override
  void initState() {
    super.initState();
    _sincronizarChaves();
    _agendarRevelar();
  }

  @override
  void didUpdateWidget(_BuscaEChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sincronizarChaves();
    if (oldWidget.selecionado != widget.selecionado ||
        oldWidget.secoes.length != widget.secoes.length) {
      _agendarRevelar();
    }
  }

  void _sincronizarChaves() {
    while (_chaves.length < widget.secoes.length) {
      _chaves.add(GlobalKey());
    }
    if (_chaves.length > widget.secoes.length) {
      _chaves.removeRange(widget.secoes.length, _chaves.length);
    }
  }

  void _agendarRevelar() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revelarSelecionado());
  }

  void _revelarSelecionado() {
    if (!mounted) return;
    final indice = widget.selecionado;
    if (indice < 0 || indice >= _chaves.length) return;
    final contexto = _chaves[indice].currentContext;
    if (contexto == null) return;
    final caixa = contexto.findRenderObject() as RenderBox?;
    final rolagem = Scrollable.maybeOf(contexto);
    if (caixa == null || !caixa.hasSize || rolagem == null) return;
    if (rolagem.position.axis != Axis.horizontal) return;
    final viewport = rolagem.context.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final origem = caixa.localToGlobal(Offset.zero, ancestor: viewport);
    final fim = origem.dx + caixa.size.width;
    final cabeNaFaixa = origem.dx >= 0 && fim <= viewport.size.width + 1;
    if (cabeNaFaixa) return;
    rolagem.position.ensureVisible(
      caixa,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final busca = widget.busca;
    final mostrarChips = widget.mostrarChips;
    final secoes = widget.secoes;
    final selecionado = widget.selecionado;
    final onChip = widget.onChip;
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(cor, Colors.white);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: TextField(
              key: const Key('busca-cardapio'),
              controller: busca,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Color(0xFF222222), fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Buscar no cardápio',
                hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                filled: true,
                fillColor: const Color(0xFFF2F2F2),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B6B6B)),
                suffixIcon: busca.text.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('limpar-busca'),
                        tooltip: 'Limpar',
                        onPressed: busca.clear,
                        icon: const Icon(Icons.close),
                        color: const Color(0xFF6B6B6B),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (mostrarChips) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                key: const Key('faixa-grupos'),
                scrollDirection: Axis.horizontal,
                itemCount: secoes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final ativo = index == selecionado;
                  final forma = formatoBotao(
                    side: ativo
                        ? BorderSide.none
                        : const BorderSide(color: Color(0xFFE6E6E6)),
                  );
                  return Material(
                    key: _chaves[index],
                    color: ativo ? cor : Colors.white,
                    shape: forma,
                    child: InkWell(
                      key: Key('chip-${secoes[index].codigoGrupo}'),
                      customBorder: forma,
                      onTap: () => onChip(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Center(
                          child: Text(
                            secoes[index].descricaoGrupo,
                            style: TextStyle(
                              color: ativo ? texto : const Color(0xFF333333),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CardProduto extends ConsumerWidget {
  final Produto produto;
  final int codigoGrupo;
  final VoidCallback onAbrir;

  const _CardProduto({
    required this.produto,
    required this.codigoGrupo,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final ingredientes = produto.ingredientes.trim();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: InkWell(
        key: Key('produto-$codigoGrupo-${produto.codigo}'),
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: FotoProduto(
                  key: ValueKey('foto-${produto.codigo}'),
                  codigo: produto.codigo,
                  extensao: config.extProd,
                  urlRede: config.urlFoto(
                    produto.codigo,
                    pagina: ref.watch(paginaAbertaProvider),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produto.descricao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (ingredientes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _DescricaoDetalhada(
                        key: ValueKey(
                          'detalhe-$codigoGrupo-${produto.codigo}',
                        ),
                        texto: ingredientes,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      formatMoney(produto.preco),
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescricaoDetalhada extends StatefulWidget {
  final String texto;

  const _DescricaoDetalhada({super.key, required this.texto});

  @override
  State<_DescricaoDetalhada> createState() => _DescricaoDetalhadaState();
}

class _DescricaoDetalhadaState extends State<_DescricaoDetalhada> {
  static const _estilo = TextStyle(
    color: Color(0xFF6B6B6B),
    fontSize: 13,
  );

  bool _aberta = false;

  bool _passaDeTresLinhas(double largura) {
    final painter = TextPainter(
      text: TextSpan(text: widget.texto, style: _estilo),
      maxLines: 3,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: largura);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final corLink = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final longa = _passaDeTresLinhas(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.texto,
              textAlign: TextAlign.start,
              maxLines: _aberta ? null : 3,
              overflow: _aberta ? TextOverflow.visible : TextOverflow.ellipsis,
              style: _estilo,
            ),
            if (longa)
              GestureDetector(
                onTap: () => setState(() => _aberta = !_aberta),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(
                    _aberta ? 'Ver menos' : 'Ver mais',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: corLink,
                      fontSize: 12,
                      height: 1.2,
                      decoration: TextDecoration.underline,
                      decorationColor: corLink,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BarraPedido extends StatelessWidget {
  final List<CartLine> carrinho;
  final VoidCallback onAbrir;

  const _BarraPedido({required this.carrinho, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final texto = corLegivelNoFundo(cor, Colors.white);
    final rotulo = rotuloPedido(
      contarItens(carrinho),
      formatMoney(somarCarrinho(carrinho)),
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Material(
        color: cor,
        borderRadius: bordaBotao,
        child: InkWell(
          key: const Key('ver-pedido'),
          borderRadius: bordaBotao,
          onTap: onAbrir,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MensagemCentro extends StatelessWidget {
  final String texto;

  const _MensagemCentro(this.texto);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          texto,
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
}

class _ErroRede extends StatelessWidget {
  final VoidCallback onRepetir;

  const _ErroRede({required this.onRepetir});

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
                  backgroundColor: cor,
                  foregroundColor: texto,
                  shape: formatoBotao(),
                  minimumSize: const Size(44, 48),
                ),
                child: const Text('Repetir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCardapio extends StatelessWidget {
  const _SkeletonCardapio();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 6; i++) ...[
          const Row(
            children: [
              _Bloco(width: 104, height: 104),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bloco(width: 160, height: 16),
                    SizedBox(height: 8),
                    _Bloco(width: 120, height: 12),
                    SizedBox(height: 12),
                    _Bloco(width: 72, height: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Bloco extends StatelessWidget {
  final double width;
  final double height;

  const _Bloco({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
