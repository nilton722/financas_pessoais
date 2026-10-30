import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_providers.dart';
import '../domain/movement.dart';
import 'transactions_providers.dart';

class MovementFormPage extends ConsumerStatefulWidget {
  const MovementFormPage({super.key, this.movementId});

  final String? movementId;

  @override
  ConsumerState<MovementFormPage> createState() => _MovementFormPageState();
}

class _MovementFormPageState extends ConsumerState<MovementFormPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  MovementKind _kind = MovementKind.income;
  String? _accountId;
  String? _destinationId;
  String? _categoryId;
  DateTime _date = FinancialDate.today();
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.movementId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _load();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final movement = await ref
        .read(transactionRepositoryProvider)
        .findById(widget.movementId!);
    if (!mounted) {
      return;
    }
    if (movement == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Movimento não encontrado.'};
      });
      return;
    }
    setState(() {
      _kind = movement.kind;
      _accountId = movement.accountId;
      _destinationId = movement.destinationAccountId;
      _categoryId = movement.categoryId;
      _date = movement.date;
      _amountController.text = MoneyInputParser.formatPlain(movement.amount);
      _descriptionController.text = movement.description ?? '';
      _notesController.text = movement.notes ?? '';
      _loading = false;
    });
  }

  void _changeKind(MovementKind kind) {
    setState(() {
      _kind = kind;
      _categoryId = null;
      _destinationId = null;
      _errors = const {};
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today(),
      helpText: 'Data do movimento',
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  /// Erros de leitura do montante têm prioridade sobre as mensagens
  /// genéricas do rascunho: são mais específicos para quem está a preencher.
  void _mergeErrors(Map<String, String> errors, Map<String, String> draft) {
    for (final entry in draft.entries) {
      errors.putIfAbsent(entry.key, () => entry.value);
    }
  }

  Future<void> _save() async {
    final amount = MoneyInputParser.parseXof(_amountController.text);
    final errors = <String, String>{};
    if (amount == null) {
      errors['amount'] = MoneyInputParser.validate(_amountController.text)!;
    }

    if (_kind.isTransfer) {
      final draft = TransferDraft(
        sourceAccountId: _accountId,
        destinationAccountId: _destinationId,
        amount: amount ?? 0,
        date: _date,
        description: _descriptionController.text,
      );
      _mergeErrors(errors, draft.validate());
      if (errors.isNotEmpty) {
        setState(() => _errors = errors);
        return;
      }
      await _persist(
        () => _isEditing
            ? ref
                  .read(transactionRepositoryProvider)
                  .updateTransfer(widget.movementId!, draft)
            : ref.read(transactionRepositoryProvider).createTransfer(draft),
      );
    } else {
      final draft = MovementDraft(
        kind: _kind,
        amount: amount ?? 0,
        date: _date,
        accountId: _accountId,
        categoryId: _categoryId,
        description: _descriptionController.text,
        notes: _notesController.text,
      );
      _mergeErrors(errors, draft.validate());
      if (errors.isNotEmpty) {
        setState(() => _errors = errors);
        return;
      }
      await _persist(
        () => _isEditing
            ? ref
                  .read(transactionRepositoryProvider)
                  .updateMovement(widget.movementId!, draft)
            : ref.read(transactionRepositoryProvider).createMovement(draft),
      );
    }
  }

  Future<void> _persist(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      await action();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Movimento atualizado.' : 'Movimento registado.',
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppFailure catch (failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errors = {'form': failure.message};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final accountItems = accounts
        .where(
          (account) =>
              !account.isArchived ||
              account.id == _accountId ||
              account.id == _destinationId,
        )
        .toList();
    final categoryKind = _kind == MovementKind.income
        ? CategoryKind.income
        : CategoryKind.expense;
    final categories =
        ref
            .watch(
              allCategoriesProvider(_kind.isTransfer ? null : categoryKind),
            )
            .value ??
        const <Category>[];
    final categoryItems = categories
        .where((category) => !category.isArchived || category.id == _categoryId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimento' : 'Novo movimento'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.page,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final kind in MovementKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: _isEditing
                            ? null
                            : (selected) {
                                if (selected) {
                                  _changeKind(kind);
                                }
                              },
                      ),
                  ],
                ),
                if (_errors['kind'] != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errors['kind']!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montante',
                    suffixText: 'FCFA',
                    errorText: _errors['amount'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data',
                      errorText: _errors['date'],
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      FinancialDate.toDisplay(
                        FinancialDate.fromDateTime(_date),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<String>(
                  label: _kind.isTransfer ? 'Conta de origem' : 'Conta',
                  value: _accountId,
                  errorText: _errors['accountId'] ?? _errors['sourceAccountId'],
                  items: [
                    for (final account in accountItems)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.isArchived
                              ? '${account.name} (arquivada)'
                              : account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _accountId = id),
                ),
                if (_kind.isTransfer) ...[
                  const SizedBox(height: AppSpacing.lg),
                  LabeledDropdown<String>(
                    label: 'Conta de destino',
                    value: _destinationId,
                    errorText: _errors['destinationAccountId'],
                    items: [
                      for (final account in accountItems)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            account.isArchived
                                ? '${account.name} (arquivada)'
                                : account.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _destinationId = id),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  LabeledDropdown<String>(
                    label: 'Categoria',
                    value: _categoryId,
                    errorText: _errors['categoryId'],
                    items: [
                      for (final category in categoryItems)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(
                            category.isArchived
                                ? '${category.name} (arquivada)'
                                : category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _categoryId = id),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    errorText: _errors['description'],
                  ),
                ),
                if (!_kind.isTransfer) ...[
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notas (opcional)',
                      errorText: _errors['notes'],
                    ),
                  ),
                ],
                if (_errors['form'] != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _errors['form']!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'A guardar…' : 'Guardar'),
                ),
              ],
            ),
    );
  }
}
