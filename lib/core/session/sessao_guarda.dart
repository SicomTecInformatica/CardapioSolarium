import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../acesso/acesso_regras.dart';
import '../config/app_config.dart';
import '../relogio.dart';
import 'app_session.dart';

bool sessaoAtualExpirada(WidgetRef ref) {
  final entrada = ref.read(appSessionProvider).horaEntrada;
  if (entrada == null) return false;
  return sessaoExpirada(
    agora: ref.read(relogioProvider)(),
    horaEntrada: entrada,
    tempoExpira: ref.read(appConfigProvider).tempoExpira,
  );
}

Future<void> encerrarSessaoExpirada(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: const Text(msgSessaoExpirada),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  await ref.read(appSessionProvider.notifier).esquecerEntrada();
  if (!context.mounted) return;
  ref.read(appSessionProvider.notifier).sair();
  context.go('/');
}
