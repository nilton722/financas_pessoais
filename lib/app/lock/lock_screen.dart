import 'package:flutter/material.dart';

import '../../core/security/device_auth_service.dart';
import '../theme/app_tokens.dart';
import 'app_lock_controller.dart';

/// Ecrã opaco apresentado enquanto a aplicação está bloqueada.
///
/// Não mostra dados financeiros e cobre por completo o conteúdo da aplicação.
class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.controller,
    required this.onUnlock,
  });

  final AppLockController controller;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final feedback = switch (controller.lastOutcome) {
      DeviceAuthOutcome.canceled => 'Desbloqueio cancelado. Tente novamente.',
      DeviceAuthOutcome.failed =>
        'Não foi possível confirmar. Tente novamente.',
      _ => null,
    };

    return Material(
      key: const Key('app-lock-screen'),
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        dark
                            ? 'assets/branding/no_dinheru_logo_dark.png'
                            : 'assets/branding/no_dinheru_logo.png',
                        key: const Key('app-lock-logo'),
                        width: 180,
                        semanticLabel:
                            'Nô Dinheru — O teu dinheiro, sob controlo.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Nô Dinheru está bloqueada',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        controller.supported
                            ? 'Desbloqueie com o PIN, padrão ou biometria do '
                                  'telefone.'
                            : 'O bloqueio do telefone não está configurado '
                                  'neste dispositivo.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (feedback != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          feedback,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      if (controller.supported)
                        FilledButton.icon(
                          key: const Key('app-lock-unlock'),
                          onPressed: controller.authenticating
                              ? null
                              : onUnlock,
                          icon: Icon(
                            controller.authenticating
                                ? Icons.lock_clock_outlined
                                : Icons.lock_open_outlined,
                          ),
                          label: Text(
                            controller.authenticating
                                ? 'A pedir desbloqueio…'
                                : 'Desbloquear',
                          ),
                        )
                      else
                        FilledButton(
                          key: const Key('app-lock-open-without'),
                          onPressed: controller.openWithoutCredentials,
                          child: const Text('Abrir sem bloqueio'),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'O bloqueio é uma barreira de interface: não cifra a '
                        'base de dados nem os backups guardados no telefone.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
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
