import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_info.dart';
import '../../../core/backup/backup_format.dart';
import '../domain/app_settings.dart';
import 'backup_providers.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final dataDirectory = ref.watch(appDataDirectoryProvider).value;
    final backupsDirectory = ref.watch(backupsDirectoryProvider).value;
    final exportsDirectory = ref.watch(exportsDirectoryProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('settings-privacy'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Privacidade',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Os dados financeiros ficam apenas neste dispositivo. '
                    'A aplicação não se liga à internet, não envia dados para '
                    'servidores e não usa analytics, anúncios, telemetria nem '
                    'contas remotas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A base SQLite e os ficheiros de backup/exportação não são '
                    'cifrados. Quem tiver acesso físico aos ficheiros (por '
                    'exemplo, num dispositivo desbloqueado ou com root) '
                    'consegue lê-los. Proteja o dispositivo e guarde cópias '
                    'fora dele.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta versão não tem PIN nem biometria. Um eventual '
                    'bloqueio de ecrã não cifra a base: é apenas uma barreira '
                    'visual. Para proteção real, use o bloqueio do sistema.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings-reports'),
                  leading: const Icon(Icons.query_stats_outlined),
                  title: const Text('Relatórios e exportação'),
                  subtitle: const Text(
                    'Resumo por período, categoria e conta; exportar CSV',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/reports'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('settings-backups'),
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup e restauração'),
                  subtitle: const Text(
                    'Criar, listar, validar e restaurar cópias dos dados',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backups'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Onde estão os dados',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _PathRow(
                    label: 'Dados',
                    path: dataDirectory,
                    onCopy: dataDirectory == null
                        ? null
                        : () => _copy(context, dataDirectory),
                  ),
                  _PathRow(
                    label: 'Backups',
                    path: backupsDirectory,
                    onCopy: backupsDirectory == null
                        ? null
                        : () => _copy(context, backupsDirectory),
                  ),
                  _PathRow(
                    label: 'Exportações',
                    path: exportsDirectory,
                    onCopy: exportsDirectory == null
                        ? null
                        : () => _copy(context, exportsDirectory),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Android, estas pastas ficam na área específica da '
                    'aplicação e não exigem permissões de armazenamento. '
                    'Pode copiar os ficheiros por USB ou por um gestor de '
                    'ficheiros. A exportação é sempre iniciada por você.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preferências', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Moeda'),
                    subtitle: Text(
                      settings?.currencyCode ??
                          AppSettings.defaults.currencyCode,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.translate_outlined),
                    title: const Text('Idioma'),
                    subtitle: Text(
                      settings?.locale ?? AppSettings.defaults.locale,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.public_outlined),
                    title: const Text('Fuso horário'),
                    subtitle: Text(
                      settings?.timeZone ?? AppSettings.defaults.timeZone,
                    ),
                  ),
                  Text(
                    'Valores configuráveis guardados localmente. A interface '
                    'de alteração pode ser adicionada numa fase futura.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Finanças Pessoais ${AppInfo.version} (${AppInfo.build}) · '
                'esquema v$backupSchemaVersion · dados apenas neste '
                'dispositivo.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Caminho copiado.')));
    }
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.path,
    required this.onCopy,
  });

  final String label;
  final String? path;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  path ?? 'A obter…',
                  style: theme.textTheme.bodySmall,
                  softWrap: true,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar caminho de $label',
            icon: const Icon(Icons.copy_outlined),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
