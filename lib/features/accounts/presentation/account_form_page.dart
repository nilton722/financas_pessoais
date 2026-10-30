import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../domain/account.dart';
import 'accounts_providers.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.accountId});

  final String? accountId;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  AccountType _type = AccountType.cash;
  DateTime _openingDate = FinancialDate.today();
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;

  bool get _isEditing => widget.accountId != null;

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
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final account = await ref
        .read(accountRepositoryProvider)
        .findById(widget.accountId!);
    if (!mounted) {
      return;
    }
    if (account == null) {
      setState(() {
        _loading = false;
        _errors = const {'name': 'Conta não encontrada.'};
      });
      return;
    }
    setState(() {
      _nameController.text = account.name;
      _balanceController.text = MoneyInputParser.formatPlain(
        account.openingBalance,
      );
      _type = account.type;
      _openingDate = account.openingDate;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(1990),
      lastDate: FinancialDate.today(),
      helpText: 'Data de abertura',
    );
    if (picked != null) {
      setState(() => _openingDate = picked);
    }
  }

  Future<void> _save() async {
    final openingBalance = MoneyInputParser.parseXof(_balanceController.text);
    final errors = <String, String>{};
    if (openingBalance == null) {
      errors['openingBalance'] = MoneyInputParser.validate(
        _balanceController.text,
      )!;
    }
    final draft = AccountDraft(
      name: _nameController.text,
      type: _type,
      openingBalance: openingBalance ?? 0,
      openingDate: _openingDate,
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
      final repository = ref.read(accountRepositoryProvider);
      if (_isEditing) {
        await repository.update(widget.accountId!, draft);
      } else {
        await repository.create(draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Conta atualizada.' : 'Conta criada.'),
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
        _errors = {'name': failure.message};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar conta' : 'Nova conta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.page,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    errorText: _errors['name'],
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.lg),
                LabeledDropdown<AccountType>(
                  label: 'Tipo',
                  value: _type,
                  items: [
                    for (final type in AccountType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (type) =>
                      setState(() => _type = type ?? AccountType.cash),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _balanceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Saldo inicial',
                    suffixText: 'FCFA',
                    errorText: _errors['openingBalance'],
                    helperText: 'Número inteiro, sem decimais.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Data de abertura',
                      errorText: _errors['openingDate'],
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      FinancialDate.toDisplay(
                        FinancialDate.fromDateTime(_openingDate),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Moeda'),
                  child: Text('FCFA (XOF)'),
                ),
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
