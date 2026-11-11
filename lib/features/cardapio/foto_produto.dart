import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/sem_cache.dart';

const _ausente = ColoredBox(color: Color(0xFFEEEEEE));

Future<Set<String>>? _arquivosDeFoto;

Future<Set<String>> arquivosDeFoto() {
  return _arquivosDeFoto ??= AssetManifest.loadFromAssetBundle(rootBundle)
      .then((manifesto) => manifesto.listAssets().toSet());
}

class FotoProduto extends StatefulWidget {
  final int codigo;
  final String extensao;
  final String urlRede;
  final double altura;
  final double largura;
  final BoxFit ajuste;

  const FotoProduto({
    super.key,
    required this.codigo,
    required this.extensao,
    required this.urlRede,
    this.altura = 104,
    this.largura = 104,
    this.ajuste = BoxFit.cover,
  });

  @override
  State<FotoProduto> createState() => _FotoProdutoState();
}

class _FotoProdutoState extends State<FotoProduto> {
  bool? _noPacote;

  @override
  void initState() {
    super.initState();
    final caminho =
        'assets/images/produtos/${widget.codigo}.${widget.extensao}';
    arquivosDeFoto().then((arquivos) {
      if (!mounted) return;
      setState(() => _noPacote = arquivos.contains(caminho));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEEEEEE),
      child: SizedBox(
        width: widget.largura,
        height: widget.altura,
        child: _imagem(),
      ),
    );
  }

  Widget _imagem() {
    if (kIsWeb && widget.urlRede.isNotEmpty) {
      return Image.network(
        widget.urlRede,
        headers: cabecalhosSemCache,
        fit: widget.ajuste,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => _doPacote(),
      );
    }
    return _doPacote();
  }

  Widget _doPacote() {
    final noPacote = _noPacote;
    if (noPacote == null || !noPacote) return _ausente;
    return Image.asset(
      'assets/images/produtos/${widget.codigo}.${widget.extensao}',
      fit: widget.ajuste,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) => _ausente,
    );
  }
}
