import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/format/money.dart';
import '../../core/network/cardapio_api.dart';
import '../../core/session/app_session.dart';
import '../../core/theme/club_theme.dart';
import '../../core/web/pagina_aberta.dart';
import '../../shared/models/produto.dart';
import 'cardapio_cache.dart';
import 'cardapio_regras.dart';
import 'foto_produto.dart';
import 'produto_regras.dart';

Future<bool> abrirProduto(
  BuildContext context, {
  required Produto produto,
  required int codigoGrupo,
}) async {
  final incluiu = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final teclado = MediaQuery.viewInsetsOf(context).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: teclado),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.94,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return _Moldura(
              child: ProdutoSheet(
                produto: produto,
                codigoGrupo: codigoGrupo,
                scroll: controller,
              ),
            );
          },
        ),
      );
    },
  );
  return incluiu ?? false;
}

class _Moldura extends StatelessWidget {
  final Widget child;

  const _Moldura({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largura =
            constraints.maxWidth > 480 ? 480.0 : constraints.maxWidth;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: largura,
            height: constraints.maxHeight,
            child: Material(
              color: Colors.white,
              elevation: 0,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class ProdutoSheet extends ConsumerStatefulWidget {
  final Produto produto;
  final int codigoGrupo;
  final ScrollController scroll;

  const ProdutoSheet({
    super.key,
    required this.produto,
    required this.codigoGrupo,
    required this.scroll,
  });

  @override
  ConsumerState<ProdutoSheet> createState() => _ProdutoSheetState();
}

class _ProdutoSheetState extends ConsumerState<ProdutoSheet>
    with WidgetsBindingObserver {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  final _campoKey = GlobalKey();
  late final Future<void> _carga;
  List<String> _opcoes = const [];
  SelecaoObservacoes _selecao = const SelecaoObservacoes();
  bool _indisponivel = false;
  String _avisoCarrinho = '';
  int _quantidade = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _texto.addListener(() {
      if (mounted) setState(() {});
    });
    _foco.addListener(() {
      if (_foco.hasFocus) _mostrarCampo();
    });
    _carga = _carregarObservacoes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_foco.hasFocus) _mostrarCampo();
  }

  Future<void> _carregarObservacoes() async {
    final cache = ref.read(cacheObservacoesProvider.notifier);
    final guardadas = cache.ler(widget.codigoGrupo);
    if (guardadas != null) {
      if (!mounted) return;
      setState(() => _opcoes = guardadas);
      return;
    }
    final api = ref.read(cardapioApiProvider);
    try {
      final resposta = await api.observacoes(widget.codigoGrupo);
      final lista = lerObservacoes(resposta.dados, resposta.corpoBruto);
      cache.guardar(widget.codigoGrupo, lista);
      if (!mounted) return;
      setState(() => _opcoes = lista);
    } on CardapioApiException {
      if (!mounted) return;
      setState(() => _indisponivel = true);
    }
  }

  void _mostrarCampo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alvo = _campoKey.currentContext;
      if (alvo == null || !mounted) return;
      Scrollable.ensureVisible(
        alvo,
        alignment: 1,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  Future<void> _enviarTexto([String? _]) async {
    await _carga;
    if (!mounted) return;
    final resultado = incluirTextoObservacao(
      _selecao,
      _texto.text,
      _opcoes,
    );
    setState(() {
      _selecao = resultado.selecao;
      _avisoCarrinho = '';
      if (resultado.limpar) _texto.clear();
    });
  }

  void _tocarChip(String descricao, {required bool livre}) {
    setState(() {
      _avisoCarrinho = '';
      if (livre) {
        _selecao = SelecaoObservacoes(
          chips: _selecao.chips,
          livres: [
            for (final item in _selecao.livres)
              if (item != descricao) item,
          ],
        );
        return;
      }
      _selecao = tocarChip(_selecao, descricao);
    });
  }

  Future<void> _confirmar() async {
    final session = ref.read(appSessionProvider);
    final resultado = fundirNoCarrinho(
      linhas: session.carrinho,
      codigo: widget.produto.codigo,
      descricao: widget.produto.descricao,
      valorUnitario: widget.produto.preco,
      quantidade: _quantidade.toDouble(),
      observacoes: _selecao.ordem,
    );
    if (!resultado.aceita) {
      setState(() => _avisoCarrinho = msgLimiteItens);
      return;
    }
    await ref
        .read(appSessionProvider.notifier)
        .substituirCarrinho(resultado.linhas);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final produto = widget.produto;
    final ingredientes = produto.ingredientes.trim();
    final cor = corBotao(Theme.of(context).colorScheme.primary);
    final textoBotao =
        corLegivelNoFundo(cor, Theme.of(context).colorScheme.onPrimary);
    final total = formatMoney(produto.preco * _quantidade);
    return Column(
      children: [
        const _Alca(),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scroll,
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FotoProduto(
                  codigo: produto.codigo,
                  extensao: config.extProd,
                  urlRede: config.urlFoto(
                    produto.codigo,
                    pagina: ref.watch(paginaAbertaProvider),
                  ),
                  altura: 160,
                  largura: double.infinity,
                  ajuste: BoxFit.contain,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    produto.descricao,
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    formatMoney(produto.preco),
                    style: const TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 16,
                    ),
                  ),
                ),
                if (ingredientes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      ingredientes,
                      style: const TextStyle(
                        color: Color(0xFF555555),
                        fontSize: 14,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      for (final info in informacoesDoProduto(produto))
                        _Info(info),
                    ],
                  ),
                ),
                if (_opcoes.isNotEmpty || _selecao.livres.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Observações',
                      style: TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opcao in _opcoes)
                          _ChipObservacao(
                            texto: opcao,
                            selecionado: _selecao.chips.contains(opcao),
                            onTap: () => _tocarChip(opcao, livre: false),
                          ),
                        for (final livre in _selecao.livres)
                          _ChipObservacao(
                            texto: livre,
                            selecionado: true,
                            onTap: () => _tocarChip(livre, livre: true),
                          ),
                      ],
                    ),
                  ),
                ],
                if (_indisponivel)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      msgObservacoesIndisponiveis,
                      style: TextStyle(color: Color(0xFF555555), fontSize: 13),
                    ),
                  ),
                Padding(
                  key: _campoKey,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('campo-observacao'),
                          controller: _texto,
                          focusNode: _foco,
                          maxLength: 50,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          maxLines: 1,
                          textInputAction: TextInputAction.done,
                          onSubmitted: _enviarTexto,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 16,
                          ),
                          scrollPadding: const EdgeInsets.only(bottom: 24),
                          decoration: InputDecoration(
                            hintText: 'Alguma observação?',
                            hintStyle:
                                const TextStyle(color: Color(0xFF8A8A8A)),
                            counterText: '${_texto.text.length}/50',
                            counterStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B6B6B),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF2F2F2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('incluir-observacao'),
                        onPressed: _enviarTexto,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                        child: const Text('Incluir'),
                      ),
                    ],
                  ),
                ),
                if (_selecao.aviso.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _selecao.aviso,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (_avisoCarrinho.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      _avisoCarrinho,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BolhaQuantidade(
                      chave: const Key('quantidade-menos'),
                      icone: Icons.remove,
                      ativo: _quantidade > 1,
                      onTap: () => setState(() => _quantidade -= 1),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '$_quantidade',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF222222),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _BolhaQuantidade(
                      chave: const Key('quantidade-mais'),
                      icone: Icons.add,
                      ativo: true,
                      onTap: () => setState(() => _quantidade += 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    key: const Key('confirmar-produto'),
                    onPressed: _confirmar,
                    style: FilledButton.styleFrom(
                      backgroundColor: cor,
                      foregroundColor: textoBotao,
                      shape: formatoBotao(),
                    ),
                    child: Text(
                      'Adicionar · $total',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Alca extends StatelessWidget {
  const _Alca();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD0D0D0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final InformacaoProduto info;

  const _Info(this.info);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icone(info.tipo), size: 16, color: const Color(0xFF555555)),
        const SizedBox(width: 4),
        Text(
          info.texto,
          style: const TextStyle(color: Color(0xFF555555), fontSize: 13),
        ),
      ],
    );
  }

  IconData _icone(TipoInformacao tipo) {
    switch (tipo) {
      case TipoInformacao.gluten:
      case TipoInformacao.semGluten:
        return Icons.breakfast_dining_outlined;
      case TipoInformacao.lactose:
      case TipoInformacao.semLactose:
        return Icons.water_drop_outlined;
      case TipoInformacao.vegano:
        return Icons.eco_outlined;
      case TipoInformacao.kcal:
        return Icons.local_fire_department_outlined;
    }
  }
}

class _ChipObservacao extends StatelessWidget {
  final String texto;
  final bool selecionado;
  final VoidCallback onTap;

  const _ChipObservacao({
    required this.texto,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final claro = corLegivelNoFundo(cor, Colors.white);
    return Material(
      color: selecionado ? cor : Colors.white,
      shape: StadiumBorder(
        side: selecionado
            ? BorderSide.none
            : const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: InkWell(
        key: Key('obs-$texto'),
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selecionado ? claro : const Color(0xFF333333),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BolhaQuantidade extends StatelessWidget {
  final Key chave;
  final IconData icone;
  final bool ativo;
  final VoidCallback onTap;

  const _BolhaQuantidade({
    required this.chave,
    required this.icone,
    required this.ativo,
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
        color: ativo ? cor : const Color(0xFFE6E6E6),
        borderRadius: bordaBotao,
        child: InkWell(
          key: chave,
          customBorder: formatoBotao(),
          onTap: ativo ? onTap : null,
          child: Icon(
            icone,
            color: ativo ? claro : const Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}
