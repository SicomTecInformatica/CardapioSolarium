import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/sessao_guarda.dart';
import 'conta_regras.dart';

class FormasPagamentoPage extends ConsumerStatefulWidget {
  const FormasPagamentoPage({super.key});

  @override
  ConsumerState<FormasPagamentoPage> createState() =>
      _FormasPagamentoPageState();
}

class _FormasPagamentoPageState extends ConsumerState<FormasPagamentoPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_guardarSessao);
  }

  Future<void> _guardarSessao() async {
    if (!mounted || !sessaoAtualExpirada(ref)) return;
    await encerrarSessaoExpirada(context, ref);
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/conta');
  }

  Future<void> _contaClube() async {
    if (sessaoAtualExpirada(ref)) {
      await encerrarSessaoExpirada(context, ref);
      return;
    }
    if (!mounted) return;
    context.push('/conta/pagamento');
  }

  Future<void> _chamarAtendente(String forma) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(avisoChamarAtendente(forma)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Material(
                  color: Colors.white,
                  child: AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    title: const Text(
                      'Pagamento',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    leading: IconButton(
                      onPressed: _voltar,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    children: [
                      const _Secao('Pagar pelo aplicativo'),
                      const SizedBox(height: 10),
                      _Cartao(
                        child: _LinhaForma(
                          chave: const Key('forma-conta-clube'),
                          icone: const _Marca(
                            cor: Color(0xFFE53935),
                            icon: Icons.receipt_long,
                          ),
                          titulo: formaContaClube,
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFFB0B0B0),
                          ),
                          onTap: _contaClube,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Outras Formas de Pagamento',
                        style: TextStyle(
                          color: Color(0xFF4A4A4A),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chamar Atendente',
                        style: TextStyle(
                          color: Color(0xFF9A9A9A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final forma in _atendente) ...[
                        _Cartao(
                          child: _LinhaForma(
                            chave: Key(forma.chave),
                            icone: forma.icone,
                            titulo: forma.nome,
                            trailing: const Icon(
                              Icons.room_service_outlined,
                              color: Color(0xFFF5A04A),
                              size: 28,
                            ),
                            onTap: () => _chamarAtendente(forma.nome),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormaAtendente {
  final String nome;
  final String chave;
  final Widget icone;

  const _FormaAtendente(this.nome, this.chave, this.icone);
}

const _atendente = [
  _FormaAtendente(
    'Pix',
    'forma-pix',
    _Marca(cor: Color(0xFF32BCAD), icon: Icons.pix),
  ),
  _FormaAtendente(
    'Dinheiro',
    'forma-dinheiro',
    _Circulo(
      fundo: Color(0xFFF0F0F0),
      icon: Icons.attach_money,
      cor: Color(0xFF8D8D8D),
    ),
  ),
  _FormaAtendente(
    'Crédito',
    'forma-credito',
    _Marca(cor: Color(0xFF9E9E9E), icon: Icons.credit_card),
  ),
  _FormaAtendente(
    'Débito',
    'forma-debito',
    _Marca(cor: Color(0xFF9E9E9E), icon: Icons.credit_card),
  ),
];

class _Secao extends StatelessWidget {
  final String texto;

  const _Secao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: Color(0xFF8A8A8A),
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  final Widget child;

  const _Cartao({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LinhaForma extends StatelessWidget {
  final Key chave;
  final Widget icone;
  final String titulo;
  final Widget trailing;
  final VoidCallback onTap;

  const _LinhaForma({
    required this.chave,
    required this.icone,
    required this.titulo,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: chave,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                icone,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  final Color cor;
  final IconData icon;

  const _Marca({required this.cor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: cor, size: 28);
  }
}

class _Circulo extends StatelessWidget {
  final Color fundo;
  final Color cor;
  final IconData icon;

  const _Circulo({
    required this.fundo,
    required this.cor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
      child: Icon(icon, color: cor, size: 22),
    );
  }
}
