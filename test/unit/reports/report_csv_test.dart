import 'dart:io';

import 'package:financas_pessoais/core/files/app_files.dart';
import 'package:financas_pessoais/features/reports/data/report_csv.dart';
import 'package:financas_pessoais/features/reports/data/report_export_service.dart';
import 'package:financas_pessoais/features/transactions/domain/movement.dart';
import 'package:flutter_test/flutter_test.dart';

MovementListItem item({
  String id = 'm1',
  MovementKind kind = MovementKind.expense,
  int amount = 1000,
  String account = 'Carteira',
  String? destination,
  String? category,
  String description = 'Mercado',
  String? notes,
}) => MovementListItem(
  movement: Movement(
    id: id,
    kind: kind,
    accountId: 'acc-$account',
    destinationAccountId: destination == null ? null : 'acc-$destination',
    categoryId: 'cat-1',
    amount: amount,
    date: DateTime(2026, 10, 15),
    description: description,
    notes: notes,
  ),
  accountName: account,
  destinationAccountName: destination,
  categoryName: category,
);

void main() {
  test('gera CSV com BOM, separador e datas DD/MM/YYYY', () {
    final csv = ReportCsv.encode([
      item(
        kind: MovementKind.income,
        amount: 125000,
        account: 'Banco',
        category: 'Salário',
        description: 'Vencimento de outubro',
      ),
      item(
        id: 'm2',
        kind: MovementKind.transfer,
        amount: 20000,
        account: 'Banco',
        destination: 'Carteira',
        description: 'Reforço da carteira',
      ),
    ]);

    expect(csv.startsWith(ReportCsv.bom), isTrue);
    final lines = csv.replaceFirst(ReportCsv.bom, '').split('\r\n');
    expect(
      lines.first,
      'Data;Tipo;Descrição;Categoria;Conta;Conta de destino;'
      'Montante (FCFA);Notas',
    );
    expect(
      lines[1],
      '15/10/2026;Rendimento;Vencimento de outubro;Salário;Banco;;125000;',
    );
    expect(
      lines[2],
      '15/10/2026;Transferência;Reforço da carteira;;Banco;Carteira;20000;',
    );
    expect(lines[3], isEmpty);
  });

  test('protege campos com separador, aspas e quebras de linha', () {
    final csv = ReportCsv.encode([
      item(
        description: 'Compra; "mercado"\nsegunda linha',
        notes: 'linha1\r\nlinha2',
        category: 'Casa',
      ),
    ]);

    expect(
      csv,
      contains('"Compra; ""mercado""\nsegunda linha"'),
      reason: 'aspas duplicadas e campo entre aspas',
    );
    expect(csv, contains('"linha1\r\nlinha2"'));
  });

  test('lista vazia produz apenas o cabeçalho', () {
    final csv = ReportCsv.encode(const []);
    final lines = csv.replaceFirst(ReportCsv.bom, '').split('\r\n');
    expect(lines.length, 2);
    expect(lines[1], isEmpty);
  });

  test('exporta para a pasta de exportações sem duplicar nomes', () async {
    final root = await Directory.systemTemp.createTemp('relatorios-teste');
    addTearDown(() => root.delete(recursive: true));
    final service = ReportExportService(
      AppFiles(rootResolver: () async => root),
    );
    final now = DateTime.utc(2026, 10, 30, 12, 30, 45);

    final first = await service.export(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      items: [item()],
      now: now,
    );
    final second = await service.export(
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      items: [item()],
      now: now,
    );

    expect(first.parent.path, endsWith(AppFiles.exportsFolder));
    expect(first.path, isNot(second.path));
    expect(await first.exists(), isTrue);
    expect(await second.exists(), isTrue);
    final bytes = await first.readAsBytes();
    expect(bytes.take(3), [
      0xEF,
      0xBB,
      0xBF,
    ], reason: 'BOM UTF-8 presente no ficheiro');
    final contents = await first.readAsString();
    expect(contents, contains('15/10/2026'));
  });
}
