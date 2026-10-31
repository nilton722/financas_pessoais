import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/backup/backup_format.dart';
import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_storage.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/plural_formatter.dart';
import '../../../core/widgets/app_data_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../forecast/presentation/forecast_providers.dart';
import '../../planning/presentation/planning_providers.dart';
import '../../reports/presentation/reports_providers.dart';
import '../../transactions/presentation/transactions_providers.dart';
import 'backup_providers.dart';
import 'settings_providers.dart';

const Map<String, String> _tableLabels = {
  'accounts': 'contas',
  'categories': 'categorias',
  'app_settings': 'configurações',
  'transactions': 'movimentos',
  'planned_items': 'compromissos',
  'planned_item_payments': 'pagamentos de compromissos',
  'recurring_rules': 'recorrências',
  'recurring_occurrences': 'ocorrências',
  'budgets': 'orçamentos',
  'savings_goals': 'metas',
  'debts': 'dívidas',
  'debt_payments': 'pagamentos de dívidas',
};

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final directory = ref.watch(appDataDirectoryProvider);
    final backups = ref.watch(backupListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup e restauração')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(backupListProvider);
          ref.invalidate(appDataDirectoryProvider);
          await ref.read(backupListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_busy) const SizedBox(height: AppSpacing.sm),
            SectionCard(
              leading: Icon(
                Icons.shield_outlined,
                color: theme.colorScheme.primary,
              ),
              title: 'Backup local e versionado',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'O backup inclui contas, categorias, movimentos, '
                    'planeamento, metas, dívidas e configurações. O '
                    'ficheiro é JSON legível e não é cifrado.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    'Pasta: ${directory.value ?? '…'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'No Android, esta pasta pertence à aplicação e não exige '
                    'permissões de armazenamento; a app nunca pede acesso '
                    'global a ficheiros. Use "Guardar backup em…" para copiar '
                    'o ficheiro para Downloads, Google Drive, OneDrive ou '
                    'outro destino escolhido no seletor do sistema; a app não '
                    'acede à rede. A partir do Android 11, a pasta '
                    'Android/data fica oculta nos gestores de ficheiros e na '
                    'transferência USB; a depuração USB (adb) continua a '
                    'permitir retirar ficheiros dessa pasta. Para recuperar '
                    'um backup de outro dispositivo, use "Importar de um '
                    'ficheiro".',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      FilledButton.icon(
                        key: const Key('backup-create'),
                        onPressed: _busy ? null : _create,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Criar backup agora'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('backup-save-to'),
                        onPressed: _busy ? null : _saveTo,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Guardar backup em…'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('backup-import'),
                        onPressed: _busy ? null : _import,
                        icon: const Icon(Icons.file_open_outlined),
                        label: const Text('Importar de um ficheiro'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Backups neste dispositivo',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (backups.hasValue && backups.value!.isNotEmpty)
                  StatusBadge(
                    PluralFormatter.count(
                      backups.value!.length,
                      'ficheiro',
                      'ficheiros',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            switch (backups) {
              AsyncData(:final value) when value.isEmpty => const Card(
                clipBehavior: Clip.antiAlias,
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Ainda sem backups',
                  message:
                      'Crie o primeiro backup e copie-o para fora do '
                      'dispositivo.',
                ),
              ),
              AsyncData(:final value) => Card(
                key: const Key('backup-list'),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final item in value) ...[
                      _BackupTile(
                        item: item,
                        onTap: _busy ? null : () => _open(item),
                      ),
                      if (item != value.last) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
              AsyncError(:final error) => Card(
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    children: [
                      Text(_message(error), textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton(
                        onPressed: () => ref.invalidate(backupListProvider),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final item = await ref.read(backupServiceProvider).createBackup();
      ref.invalidate(backupListProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup criado: ${item.file.fileName} '
            '(${PluralFormatter.count(item.totalRows, 'registo', 'registos')}).',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _saveTo() async {
    setState(() => _busy = true);
    BackupListItem? created;
    try {
      final service = ref.read(backupServiceProvider);
      created = await service.createBackup();
      ref.invalidate(backupListProvider);
      final contents = await ref.read(backupStorageProvider).read(created.file);
      final saved = await ref.read(backupFileSaverProvider)(
        fileName: created.file.fileName,
        contents: contents,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Backup guardado no destino escolhido: '
                      '${created.file.fileName}.'
                : 'Backup criado na aplicação, mas não foi guardado fora '
                      'do dispositivo.',
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created == null
                  ? failure.message
                  : '${failure.message} A cópia local foi mantida.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final picked = await ref.read(backupFilePickerProvider)();
      if (picked == null) {
        return;
      }
      final snapshot = BackupSnapshot.decode(picked.contents);
      if (!mounted) {
        return;
      }
      final item = BackupListItem(
        file: StoredBackup(
          fileName: picked.fileName,
          path: picked.fileName,
          sizeBytes: utf8.encode(picked.contents).length,
          modifiedAt: DateTime.now(),
        ),
        snapshot: snapshot,
      );
      setState(() => _busy = false);
      await _open(item, externalContents: picked.contents);
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _open(BackupListItem item, {String? externalContents}) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.file.fileName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (externalContents != null) ...[
                Text(
                  'Ficheiro importado de fora da aplicação. Restaurar '
                  'substitui os dados atuais pelos deste documento.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _BackupDetails(item: item),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Fechar'),
          ),
          if (item.isValid)
            FilledButton(
              key: const Key('backup-restore'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restaurar'),
            ),
        ],
      ),
    );
    if (proceed != true || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar este backup?'),
        content: Text(
          'Todos os dados atuais serão substituídos pelos dados do backup '
          '${item.file.fileName}, criado em '
          '${_formatDateTime(item.snapshot!.createdAt)}.\n\n'
          'Antes de substituir, a aplicação cria automaticamente uma cópia '
          'de segurança da base atual. Ainda assim, confirme que é o '
          'ficheiro certo: a substituição não pode ser anulada dentro da '
          'aplicação.\n\n'
          'Conteúdo: ${_countsSummary(item.snapshot!)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('backup-confirm-restore'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Substituir dados'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _restore(item, externalContents: externalContents);
  }

  Future<void> _restore(BackupListItem item, {String? externalContents}) async {
    setState(() => _busy = true);
    try {
      final service = ref.read(backupServiceProvider);
      final outcome = externalContents == null
          ? await service.restore(item)
          : await service.restoreExternal(externalContents);
      if (!mounted) {
        return;
      }
      // A substituição já terminou: limpar a barra antes de abrir o diálogo,
      // para não deixar uma animação por trás da confirmação.
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Backup restaurado'),
          content: Text(
            'Os dados foram substituídos por '
            '${PluralFormatter.count(outcome.snapshot.totalRows, 'registo', 'registos')} '
            'do backup.\n\n'
            'Cópia automática da base anterior: '
            '${outcome.safetyBackup.fileName}.\n\n'
            'Se restaurou por engano, pode abrir essa cópia na lista e '
            'restaurá-la.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Concluir'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      // Só recarrega a interface depois de o diálogo fechar, para não mostrar
      // indicadores de carregamento por trás da confirmação.
      _invalidateEverything();
    } on AppFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
        ref.invalidate(backupListProvider);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _invalidateEverything() {
    ref
      ..invalidate(backupListProvider)
      ..invalidate(appDataDirectoryProvider)
      ..invalidate(exportsDirectoryProvider)
      ..invalidate(appSettingsProvider)
      ..invalidate(accountBalancesProvider)
      ..invalidate(movementListProvider)
      ..invalidate(plannedItemsProvider)
      ..invalidate(pendingPlannedItemsProvider)
      ..invalidate(recurringRulesProvider)
      ..invalidate(budgetsProvider)
      ..invalidate(savingsGoalsProvider)
      ..invalidate(debtsProvider)
      ..invalidate(forecastBundleProvider)
      ..invalidate(reportDataProvider);
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({required this.item, required this.onTap});

  final BackupListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = item.snapshot;
    final valid = item.isValid;
    return ListTile(
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: valid
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          borderRadius: AppRadii.control,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            valid ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: valid
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onErrorContainer,
          ),
        ),
      ),
      title: Text(
        item.file.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        valid
            ? '${_formatDateTime(snapshot!.createdAt)} · '
                  '${PluralFormatter.count(item.totalRows, 'registo', 'registos')} · '
                  '${_formatSize(item.file.sizeBytes)}'
            : item.error ?? 'Backup inválido',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _BackupDetails extends StatelessWidget {
  const _BackupDetails({required this.item});

  final BackupListItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = item.snapshot;
    if (snapshot == null) {
      return Text(
        '${item.error ?? 'Ficheiro inválido.'}\n\n'
        'Este ficheiro não pode ser restaurado. Pode apagá-lo ou substituí-lo '
        'por um backup criado por esta aplicação.',
        style: theme.textTheme.bodyMedium,
      );
    }
    final counts = [
      for (final table in backupTableNames)
        if ((snapshot.counts[table] ?? 0) > 0)
          '${snapshot.counts[table]} ${_tableLabels[table] ?? table}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppDataRow(
          label: 'Criado em',
          value: Text(_formatDateTime(snapshot.createdAt)),
        ),
        AppDataRow(
          label: 'Versão',
          value: Text(
            'app ${snapshot.appVersion} · esquema v$backupSchemaVersion',
          ),
        ),
        AppDataRow(
          label: 'Dimensão',
          value: Text(
            '${PluralFormatter.count(snapshot.totalRows, 'registo', 'registos')} · '
            '${_formatSize(item.file.sizeBytes)}',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Integridade verificada (${snapshot.checksum}).',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Conteúdo', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          counts.isEmpty
              ? 'Backup sem dados de utilizador.'
              : counts.join(', '),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Ao restaurar, os dados atuais são substituídos. É criada uma cópia '
          'automática antes da substituição.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _message(Object error) =>
    error is AppFailure ? error.message : 'Não foi possível ler os backups.';

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date = FinancialDate.toDisplay(FinancialDate.fromDateTime(local));
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}

String _formatSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _countsSummary(BackupSnapshot snapshot) {
  final parts = [
    for (final table in backupTableNames)
      if ((snapshot.counts[table] ?? 0) > 0)
        '${snapshot.counts[table]} ${_tableLabels[table] ?? table}',
  ];
  if (parts.isEmpty) {
    return 'backup sem dados';
  }
  return parts.join(', ');
}
