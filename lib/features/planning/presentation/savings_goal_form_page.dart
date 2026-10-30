import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../domain/savings_goal.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class SavingsGoalFormPage extends ConsumerStatefulWidget {
  const SavingsGoalFormPage({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<SavingsGoalFormPage> createState() =>
      _SavingsGoalFormPageState();
}

class _SavingsGoalFormPageState extends ConsumerState<SavingsGoalFormPage> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _targetDate;
  String? _accountId;
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.goalId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final goal = await ref
        .read(savingsGoalRepositoryProvider)
        .findById(widget.goalId!);
    if (!mounted) {
      return;
    }
    if (goal == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Meta não encontrada.'};
      });
      return;
    }
    setState(() {
      _nameController.text = goal.name;
      _targetController.text = MoneyInputParser.formatPlain(goal.targetAmount);
      _notesController.text = goal.notes ?? '';
      _targetDate = goal.targetDate;
      _accountId = goal.linkedAccountId;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _targetDate ?? FinancialDate.today().add(const Duration(days: 180)),
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today().add(const Duration(days: 3650)),
      helpText: 'Data-alvo da meta',
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _save() async {
    final target = MoneyInputParser.parseXof(_targetController.text);
    final errors = <String, String>{};
    if (target == null) {
      errors['targetAmount'] = MoneyInputParser.validate(
        _targetController.text,
      )!;
    }
    final draft = SavingsGoalDraft(
      name: _nameController.text,
      targetAmount: target ?? 0,
      targetDate: _targetDate,
      linkedAccountId: _accountId,
      notes: _notesController.text,
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
      final repository = ref.read(savingsGoalRepositoryProvider);
      if (_isEditing) {
        await repository.update(widget.goalId!, draft);
      } else {
        await repository.create(draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Meta atualizada.' : 'Meta criada.'),
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar meta' : 'Nova meta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    border: const OutlineInputBorder(),
                    errorText: _errors['name'],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Alvo',
                    suffixText: 'FCFA',
                    border: const OutlineInputBorder(),
                    errorText: _errors['targetAmount'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tem data-alvo'),
                  value: _targetDate != null,
                  onChanged: (enabled) => setState(() {
                    _targetDate = enabled
                        ? FinancialDate.today().add(const Duration(days: 180))
                        : null;
                  }),
                ),
                if (_targetDate != null)
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data-alvo',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(formatDate(_targetDate!)),
                    ),
                  ),
                const SizedBox(height: 16),
                LabeledDropdown<String>(
                  label: 'Conta associada (opcional)',
                  value: _accountId ?? '',
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Sem conta associada'),
                    ),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: const OutlineInputBorder(),
                    errorText: _errors['notes'],
                  ),
                ),
                if (_errors['form'] != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errors['form']!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'A guardar…' : 'Guardar'),
                ),
              ],
            ),
    );
  }
}
