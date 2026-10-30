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
import '../domain/planned_item.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class CommitmentFormPage extends ConsumerStatefulWidget {
  const CommitmentFormPage({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<CommitmentFormPage> createState() => _CommitmentFormPageState();
}

class _CommitmentFormPageState extends ConsumerState<CommitmentFormPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlannedItemKind _kind = PlannedItemKind.expense;
  DateTime _dueDate = FinancialDate.today();
  String? _accountId;
  String? _categoryId;
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;
  bool _locked = false;

  bool get _isEditing => widget.itemId != null;

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final item = await ref
        .read(planningRepositoryProvider)
        .findItem(widget.itemId!);
    if (!mounted) {
      return;
    }
    if (item == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Compromisso não encontrado.'};
        _locked = true;
      });
      return;
    }
    setState(() {
      _kind = item.kind;
      _dueDate = item.dueDate;
      _accountId = item.accountId;
      _categoryId = item.categoryId;
      _amountController.text = MoneyInputParser.formatPlain(item.amount);
      _descriptionController.text = item.description;
      _locked = !item.isOpen;
      _loading = false;
    });
  }

  void _changeKind(PlannedItemKind kind) {
    setState(() {
      _kind = kind;
      _categoryId = null;
      _errors = const {};
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today().add(const Duration(days: 3650)),
      helpText: 'Data de vencimento',
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = MoneyInputParser.parseXof(_amountController.text);
    final errors = <String, String>{};
    if (amount == null) {
      errors['amount'] = MoneyInputParser.validate(_amountController.text)!;
    }
    final draft = PlannedItemDraft(
      kind: _kind,
      amount: amount ?? 0,
      dueDate: _dueDate,
      description: _descriptionController.text,
      accountId: _accountId,
      categoryId: _categoryId,
    );
    errors.addAll(draft.validate());
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _errors = const {};
    });
    try {
      final repository = ref.read(planningRepositoryProvider);
      if (_isEditing) {
        await repository.updateItem(widget.itemId!, draft);
      } else {
        await repository.createItem(draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Compromisso atualizado.' : 'Compromisso criado.',
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
    final accounts =
        ref.watch(activeAccountsProvider).value ?? const <Account>[];
    final categories =
        ref
            .watch(
              allCategoriesProvider(
                _kind == PlannedItemKind.income
                    ? CategoryKind.income
                    : CategoryKind.expense,
              ),
            )
            .value ??
        const <Category>[];
    final categoryItems = categories
        .where((category) => !category.isArchived || category.id == _categoryId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar compromisso' : 'Novo compromisso'),
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
                    for (final kind in PlannedItemKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: _locked
                            ? null
                            : (selected) {
                                if (selected) {
                                  _changeKind(kind);
                                }
                              },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _amountController,
                  enabled: !_locked,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    suffixText: 'FCFA',
                    errorText: _errors['amount'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _locked ? null : _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Vencimento',
                      errorText: _errors['dueDate'],
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatDate(_dueDate)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
                  enabled: !_locked,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    errorText: _errors['description'],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<String>(
                  label: 'Conta (opcional)',
                  value: _accountId ?? '',
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sem conta')),
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _locked
                      ? (_) {}
                      : (id) => setState(
                          () => _accountId = (id == null || id.isEmpty)
                              ? null
                              : id,
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<String>(
                  label: 'Categoria (opcional)',
                  value: _categoryId ?? '',
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sem categoria'),
                    ),
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
                  onChanged: _locked
                      ? (_) {}
                      : (id) => setState(
                          () => _categoryId = (id == null || id.isEmpty)
                              ? null
                              : id,
                        ),
                ),
                if (_locked) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Este compromisso já está liquidado ou cancelado. '
                    'Para o alterar, reverta o movimento associado.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
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
                  onPressed: _saving || _locked ? null : _save,
                  child: Text(_saving ? 'A guardar…' : 'Guardar'),
                ),
              ],
            ),
    );
  }
}
