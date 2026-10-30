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
import '../domain/recurrence.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class RecurrenceFormPage extends ConsumerStatefulWidget {
  const RecurrenceFormPage({super.key, this.ruleId});

  final String? ruleId;

  @override
  ConsumerState<RecurrenceFormPage> createState() => _RecurrenceFormPageState();
}

class _RecurrenceFormPageState extends ConsumerState<RecurrenceFormPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlannedItemKind _kind = PlannedItemKind.expense;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _startDate = FinancialDate.today();
  DateTime? _endDate;
  String? _accountId;
  String? _categoryId;
  bool _lockedStructure = false;
  bool _loading = false;
  bool _saving = false;
  Map<String, String> _errors = const {};

  bool get _isEditing => widget.ruleId != null;

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
    final repository = ref.read(planningRepositoryProvider);
    final rule = await repository.findRule(widget.ruleId!);
    if (!mounted) {
      return;
    }
    if (rule == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Recorrência não encontrada.'};
      });
      return;
    }
    final occurrences = await repository.occurrenceCount(rule.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _kind = rule.kind;
      _frequency = rule.frequency;
      _startDate = rule.startDate;
      _endDate = rule.endDate;
      _accountId = rule.accountId;
      _categoryId = rule.categoryId;
      _amountController.text = MoneyInputParser.formatPlain(rule.amount);
      _descriptionController.text = rule.description;
      _lockedStructure = occurrences > 0;
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

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today().add(const Duration(days: 3650)),
      helpText: 'Início da recorrência',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: FinancialDate.today().add(const Duration(days: 3650)),
      helpText: 'Fim da recorrência',
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = MoneyInputParser.parseXof(_amountController.text);
    final errors = <String, String>{};
    if (amount == null) {
      errors['amount'] = MoneyInputParser.validate(_amountController.text)!;
    }
    final draft = RecurringRuleDraft(
      kind: _kind,
      amount: amount ?? 0,
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
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
        await repository.updateRule(widget.ruleId!, draft);
      } else {
        await repository.createRule(draft);
      }
      await repository.syncRecurrences(
        horizon: FinancialDate.today().add(const Duration(days: 90)),
      );
      ref
        ..invalidate(recurringRulesProvider)
        ..invalidate(plannedItemsProvider)
        ..invalidate(pendingPlannedItemsProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Recorrência atualizada.' : 'Recorrência criada.',
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
        title: Text(_isEditing ? 'Editar recorrência' : 'Nova recorrência'),
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
                        onSelected: _lockedStructure
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
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor por ocorrência',
                    suffixText: 'FCFA',
                    errorText: _errors['amount'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<RecurrenceFrequency>(
                  label: 'Frequência',
                  value: _frequency,
                  items: [
                    for (final frequency in RecurrenceFrequency.values)
                      DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency.label),
                      ),
                  ],
                  onChanged: _lockedStructure
                      ? (_) {}
                      : (frequency) => setState(
                          () => _frequency =
                              frequency ?? RecurrenceFrequency.monthly,
                        ),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _lockedStructure ? null : _pickStart,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Início',
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                      helperText: _lockedStructure
                          ? 'Já existem ocorrências geradas; o início e a '
                                'frequência não podem ser alterados.'
                          : null,
                    ),
                    child: Text(formatDate(_startDate)),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tem data de fim'),
                  value: _endDate != null,
                  onChanged: (enabled) => setState(() {
                    _endDate = enabled
                        ? _startDate.add(const Duration(days: 365))
                        : null;
                  }),
                ),
                if (_endDate != null)
                  InkWell(
                    onTap: _pickEnd,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Fim',
                        errorText: _errors['endDate'],
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(formatDate(_endDate!)),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
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
                  onChanged: (id) => setState(
                    () => _accountId = (id == null || id.isEmpty) ? null : id,
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
                  onChanged: (id) => setState(
                    () => _categoryId = (id == null || id.isEmpty) ? null : id,
                  ),
                ),
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
