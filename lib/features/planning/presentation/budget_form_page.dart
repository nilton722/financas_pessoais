import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/formatters/date_formatter.dart';
import '../../../core/formatters/money_input_parser.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/categories_providers.dart';
import '../domain/budget.dart';
import 'planning_format.dart';
import 'planning_providers.dart';

class BudgetFormPage extends ConsumerStatefulWidget {
  const BudgetFormPage({super.key});

  @override
  ConsumerState<BudgetFormPage> createState() => _BudgetFormPageState();
}

class _BudgetFormPageState extends ConsumerState<BudgetFormPage> {
  final _limitController = TextEditingController();

  String? _categoryId;
  late DateTime _month;
  Map<String, String> _errors = const {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _month = ref.read(budgetMonthProvider);
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: FinancialDate.today().add(const Duration(days: 730)),
      helpText: 'Mês do orçamento',
    );
    if (picked != null) {
      setState(() => _month = BudgetPeriod.monthStart(picked));
    }
  }

  Future<void> _save() async {
    final limit = MoneyInputParser.parseXof(_limitController.text);
    final errors = <String, String>{};
    if (limit == null) {
      errors['limitAmount'] = MoneyInputParser.validate(_limitController.text)!;
    }
    final draft = BudgetDraft(
      categoryId: _categoryId,
      limitAmount: limit ?? 0,
      periodStart: _month,
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
      await ref.read(budgetRepositoryProvider).save(draft);
      ref.read(budgetMonthProvider.notifier).setMonth(_month);
      messenger.showSnackBar(
        const SnackBar(content: Text('Orçamento guardado.')),
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
    final categories =
        ref.watch(activeCategoriesProvider(CategoryKind.expense)).value ??
        const <Category>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Novo orçamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledDropdown<String>(
            label: 'Categoria de despesa',
            value: _categoryId,
            errorText: _errors['categoryId'],
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickMonth,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Mês',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(formatMonth(_month)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Limite mensal',
              suffixText: 'FCFA',
              border: const OutlineInputBorder(),
              errorText: _errors['limitAmount'],
              helperText:
                  'Se já existir um orçamento para esta categoria e mês, '
                  'o limite é atualizado.',
            ),
          ),
          if (_errors['form'] != null) ...[
            const SizedBox(height: 16),
            Text(
              _errors['form']!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
