import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/app_data_row.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/section_card.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/accounts_providers.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_providers.dart';
import '../domain/debt.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class PayDebtPage extends ConsumerStatefulWidget {
  const PayDebtPage({super.key, required this.debtId});

  final String debtId;

  @override
  ConsumerState<PayDebtPage> createState() => _PayDebtPageState();
}

class _PayDebtPageState extends ConsumerState<PayDebtPage> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  Debt? _debt;
  DateTime _date = FinancialDate.today();
  String? _accountId;
  String? _categoryId;
  Map<String, String> _errors = const {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final debt = await ref.read(debtRepositoryProvider).findById(widget.debtId);
    if (!mounted) {
      return;
    }
    if (debt == null) {
      setState(() {
        _loading = false;
        _errors = const {'form': 'Dívida não encontrada.'};
      });
      return;
    }
    setState(() {
      _debt = debt;
      _amountController.text = MoneyInputParser.formatPlain(debt.remaining);
      _descriptionController.text = debt.description;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today(),
      helpText: 'Data do pagamento',
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    final debt = _debt;
    if (debt == null) {
      return;
    }
    final amount = MoneyInputParser.parseXof(_amountController.text);
    final errors = <String, String>{};
    if (amount == null) {
      errors['amount'] = MoneyInputParser.validate(_amountController.text)!;
    }
    final draft = DebtPaymentDraft(
      amount: amount ?? 0,
      date: _date,
      accountId: _accountId,
      categoryId: _categoryId,
      description: _descriptionController.text,
    );
    errors.addAll(draft.validate(remaining: debt.remaining));
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
      await ref.read(debtRepositoryProvider).pay(debt.id, draft);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pagamento registado.')),
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
    final debt = _debt;
    final categoryKind = debt?.kind == DebtKind.receivable
        ? CategoryKind.income
        : CategoryKind.expense;
    final accounts =
        ref.watch(activeAccountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(activeCategoriesProvider(categoryKind)).value ??
        const <Category>[];
    final accountId = accounts.any((account) => account.id == _accountId)
        ? _accountId
        : null;
    final categoryId = categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          debt?.kind == DebtKind.receivable
              ? 'Registar recebimento'
              : 'Pagar dívida',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : debt == null
          ? Center(
              child: Padding(
                padding: AppSpacing.page,
                child: Text(_errors['form'] ?? 'Dívida não encontrada.'),
              ),
            )
          : ListView(
              padding: AppSpacing.page,
              children: [
                SectionCard(
                  title: '${debt.description} · ${debt.kind.label}',
                  subtitle: [
                    if (debt.counterparty != null) debt.counterparty!,
                    if (debt.dueDate != null)
                      'vence ${formatDate(debt.dueDate!)}',
                  ].join(' · '),
                  child: Column(
                    children: [
                      AppDataRow(
                        label: 'Valor',
                        value: MoneyText(
                          debt.originalAmount,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      AppDataRow(
                        label: 'Pago',
                        value: MoneyText(
                          debt.paidTotal,
                          style: Theme.of(context).textTheme.bodyMedium,
                          tone: MoneyTone.income,
                        ),
                      ),
                      AppDataRow(
                        label: 'Falta',
                        value: MoneyText(
                          debt.remaining,
                          style: Theme.of(context).textTheme.bodyMedium,
                          tone: debt.isOpen
                              ? MoneyTone.warning
                              : MoneyTone.neutral,
                        ),
                        emphasize: debt.isOpen,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _amountController,
                  enabled: debt.isOpen,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Valor do pagamento',
                    suffixText: 'FCFA',
                    errorText: _errors['amount'],
                    helperText: 'Pagamento total ou parcial, até ao restante.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: debt.isOpen ? _pickDate : null,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data do pagamento',
                      errorText: _errors['date'],
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatDate(_date)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<String>(
                  label: 'Conta',
                  value: accountId,
                  errorText: _errors['accountId'],
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: debt.isOpen
                      ? (id) => setState(() => _accountId = id)
                      : (_) {},
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<String>(
                  label: 'Categoria',
                  value: categoryId,
                  errorText: _errors['categoryId'],
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: debt.isOpen
                      ? (id) => setState(() => _categoryId = id)
                      : (_) {},
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descriptionController,
                  enabled: debt.isOpen,
                  decoration: InputDecoration(
                    labelText: 'Descrição do movimento',
                    errorText: _errors['description'],
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
                  onPressed: _saving || !debt.isOpen ? null : _save,
                  child: Text(_saving ? 'A registar…' : 'Registar pagamento'),
                ),
                if (!debt.isOpen) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Esta dívida já não tem valor em falta.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}
