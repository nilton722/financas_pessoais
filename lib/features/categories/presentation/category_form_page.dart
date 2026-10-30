import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/labeled_dropdown.dart';
import '../domain/category.dart';
import 'categories_providers.dart';

class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, this.categoryId});

  final String? categoryId;

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _nameController = TextEditingController();

  CategoryKind _kind = CategoryKind.expense;
  Map<String, String> _errors = const {};
  bool _loading = false;
  bool _saving = false;
  bool _isSystem = false;

  bool get _isEditing => widget.categoryId != null;

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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final category = await ref
        .read(categoryRepositoryProvider)
        .findById(widget.categoryId!);
    if (!mounted) {
      return;
    }
    if (category == null) {
      setState(() {
        _loading = false;
        _errors = const {'name': 'Categoria não encontrada.'};
      });
      return;
    }
    setState(() {
      _nameController.text = category.name;
      _kind = category.kind;
      _isSystem = category.isSystem;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final draft = CategoryDraft(name: _nameController.text, kind: _kind);
    final errors = <String, String>{};
    if (_nameController.text.trim().isEmpty) {
      errors['name'] = 'Indique o nome da categoria.';
    }
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
      final repository = ref.read(categoryRepositoryProvider);
      if (_isEditing) {
        await repository.update(widget.categoryId!, draft);
      } else {
        await repository.create(draft);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Categoria atualizada.' : 'Categoria criada.',
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
        _errors = {'name': failure.message};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar categoria' : 'Nova categoria'),
      ),
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
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 16),
                if (_isEditing)
                  const InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      'O tipo de uma categoria não pode ser alterado.',
                    ),
                  )
                else
                  LabeledDropdown<CategoryKind>(
                    label: 'Tipo',
                    value: _kind,
                    items: [
                      for (final kind in CategoryKind.values)
                        DropdownMenuItem(value: kind, child: Text(kind.label)),
                    ],
                    onChanged: (kind) =>
                        setState(() => _kind = kind ?? CategoryKind.expense),
                  ),
                if (_isSystem) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Categoria predefinida pela aplicação. Pode ser renomeada '
                    'ou arquivada.',
                    style: Theme.of(context).textTheme.bodySmall,
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
