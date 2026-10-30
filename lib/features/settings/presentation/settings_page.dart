import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/app_info.dart';
import '../../../core/backup/backup_format.dart';
import '../../../core/widgets/section_card.dart';
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          SectionCard(
            key: const Key('settings-privacy'),
            leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
            title: 'Privacidade',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Os dados financeiros ficam apenas neste dispositivo. '
                  'A aplicação não se liga à internet, não envia dados para '
                  'servidores e não usa analytics, anúncios, telemetria nem '
                  'contas remotas.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'A base SQLite e os ficheiros de backup/exportação não são '
                  'cifrados. Quem tiver acesso físico aos ficheiros (por '
                  'exemplo, num dispositivo desbloqueado ou com root) '
                  'consegue lê-los. Proteja o dispositivo e guarde cópias '
                  'fora dele.',
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Esta versão não tem PIN nem biometria. Um eventual '
                  'bloqueio de ecrã não cifra a base: é apenas uma barreira '
                  'visual. Para proteção real, use o bloqueio do sistema.',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            clipBehavior: Clip.antiAlias,
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
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Onde estão os dados',
            subtitle: 'Pastas locais da aplicação',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Preferências',
            subtitle: 'Valores guardados localmente',
            child: Column(
              children: [
                _PreferenceRow(
                  icon: Icons.payments_outlined,
                  label: 'Moeda',
                  value:
                      settings?.currencyCode ??
                      AppSettings.defaults.currencyCode,
                ),
                const Divider(height: 1),
                _PreferenceRow(
                  icon: Icons.translate_outlined,
                  label: 'Idioma',
                  value: settings?.locale ?? AppSettings.defaults.locale,
                ),
                const Divider(height: 1),
                _PreferenceRow(
                  icon: Icons.public_outlined,
                  label: 'Fuso horário',
                  value: settings?.timeZone ?? AppSettings.defaults.timeZone,
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'A interface de alteração pode ser adicionada numa fase '
                    'futura.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Finanças Pessoais ${AppInfo.version} (${AppInfo.build}) · '
            'esquema v$backupSchemaVersion · dados apenas neste dispositivo.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.xxs),
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

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
