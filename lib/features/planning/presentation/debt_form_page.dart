import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../domain/debt.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class DebtFormPage extends ConsumerStatefulWidget {
  const DebtFormPage({super.key, this.debtId});

  final String? debtId;

  @override
  ConsumerState<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends ConsumerState<DebtFormPage> {
  final _descriptionController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _amountController = TextEditingController();

  DebtKind _kind = DebtKind.payable;
  DateTime? _dueDate;
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;
  bool _locked = false;

  bool get _isEditing => widget.debtId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _load();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final debt = await ref
        .read(debtRepositoryProvider)
        .findById(widget.debtId!);
    if (!mounted) {
      return;
    }
    if (debt == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Dívida não encontrada.'};
        _locked = true;
      });
      return;
    }
    setState(() {
      _kind = debt.kind;
      _descriptionController.text = debt.description;
      _counterpartyController.text = debt.counterparty ?? '';
      _amountController.text = MoneyInputParser.formatPlain(
        debt.originalAmount,
      );
      _dueDate = debt.dueDate;
      _locked = !debt.isOpen;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dueDate ?? FinancialDate.today().add(const Duration(days: 30)),
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today().add(const Duration(days: 3650)),
      helpText: 'Vencimento da dívida',
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    final amount = MoneyInputParser.parseXof(_amountController.text);
    final errors = <String, String>{};
    if (amount == null) {
      errors['originalAmount'] = MoneyInputParser.validate(
        _amountController.text,
      )!;
    }
    final draft = DebtDraft(
      kind: _kind,
      description: _descriptionController.text,
      originalAmount: amount ?? 0,
      counterparty: _counterpartyController.text,
      dueDate: _dueDate,
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
      final repository = ref.read(debtRepositoryProvider);
      if (_isEditing) {
        await repository.update(widget.debtId!, draft);
      } else {
        await repository.create(draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Dívida atualizada.' : 'Dívida criada.'),
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
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar dívida' : 'Nova dívida')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in DebtKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: _locked
                            ? null
                            : (selected) {
                                if (selected) {
                                  setState(() => _kind = kind);
                                }
                              },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  enabled: !_locked,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    border: const OutlineInputBorder(),
                    errorText: _errors['description'],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _counterpartyController,
                  enabled: !_locked,
                  decoration: InputDecoration(
                    labelText: 'Contraparte (opcional)',
                    border: const OutlineInputBorder(),
                    errorText: _errors['counterparty'],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  enabled: !_locked,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor original',
                    suffixText: 'FCFA',
                    border: const OutlineInputBorder(),
                    errorText: _errors['originalAmount'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tem vencimento'),
                  value: _dueDate != null,
                  onChanged: _locked
                      ? null
                      : (enabled) => setState(() {
                          _dueDate = enabled
                              ? FinancialDate.today().add(
                                  const Duration(days: 30),
                                )
                              : null;
                        }),
                ),
                if (_dueDate != null)
                  InkWell(
                    onTap: _locked ? null : _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Vencimento',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(formatDate(_dueDate!)),
                    ),
                  ),
                if (_locked) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Esta dívida já está liquidada ou cancelada. '
                    'Para a alterar, reverta os movimentos associados.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
                  onPressed: _saving || _locked ? null : _save,
                  child: Text(_saving ? 'A guardar…' : 'Guardar'),
                ),
              ],
            ),
    );
  }
}
