import 'dart:io';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../state/local_mode.dart';
import '../state/toast.dart';
import 'common.dart';

/// The question about the system's backup, asked whenever the data starts living only on the device.
const backupQuestion = 'Guardar uma cópia no backup do celular?';

String get backupExplanation => 'Sem conta, seus dados ficam só neste aparelho. O backup do ${Platform.isIOS ? 'iCloud' : 'Google'} '
    'pode guardar uma cópia junto com o resto do celular, para você não perder nada se trocar de aparelho.\n\n'
    'Você pode mudar isso depois nos ajustes.';

/// Asks [backupQuestion] in a sheet and turns the backup on when the person agrees.
Future<void> askForBackup(BuildContext context) async {
  final enable = await showSheet<bool>(
    context,
    title: backupQuestion,
    description: backupExplanation,
    body: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActionButton(label: 'Ativar o backup', onPressed: () => Navigator.of(context).pop(true)),
        const SizedBox(height: 4),
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Agora não')),
      ],
    ),
  );
  if (enable != true) return;
  try {
    await LocalMode.instance.setBackup(true);
  } catch (err) {
    toast('Não foi possível ativar o backup', description: errorMessage(err), tone: ToastTone.error);
  }
}
