import 'dart:convert';

import 'package:financas_pessoais/core/backup/backup_format.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BackupSnapshot snapshot() => BackupSnapshot.create(
    createdAt: DateTime.utc(2026, 10, 30, 12),
    settings: const {
      'currency_code': 'XOF',
      'locale': 'pt_PT',
      'time_zone': 'Africa/Bissau',
    },
    tables: {
      for (final table in backupTableNames)
        table: const <Map<String, Object?>>[],
    },
  );

  test('codifica e volta a ler o mesmo instantâneo', () {
    final original = snapshot();
    final decoded = BackupSnapshot.decode(original.toJsonString());

    expect(decoded.checksum, original.checksum);
    expect(decoded.createdAt, original.createdAt);
    expect(decoded.currencyCode, 'XOF');
    expect(decoded.locale, 'pt_PT');
    expect(decoded.totalRows, 0);
    expect(decoded.counts.keys, containsAll(backupTableNames));
  });

  test('rejeita versões de formato e esquema não suportadas', () {
    final document =
        jsonDecode(snapshot().toJsonString()) as Map<String, dynamic>;

    final newerFormat = Map<String, dynamic>.from(document)
      ..['formatVersion'] = backupFormatVersion + 1;
    expect(
      () => BackupSnapshot.decode(jsonEncode(newerFormat)),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('versão mais recente'),
        ),
      ),
    );

    final newerSchema = Map<String, dynamic>.from(document)
      ..['schemaVersion'] = backupSchemaVersion + 1;
    expect(
      () => BackupSnapshot.decode(jsonEncode(newerSchema)),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('esquema'),
        ),
      ),
    );
  });

  test('rejeita checksum ou estrutura corrompidos', () {
    final document =
        jsonDecode(snapshot().toJsonString()) as Map<String, dynamic>;
    final corrupted = Map<String, dynamic>.from(document)
      ..['checksum'] = 'deadbeef';
    expect(
      () => BackupSnapshot.decode(jsonEncode(corrupted)),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('checksum'),
        ),
      ),
    );

    expect(
      () => BackupSnapshot.decode('{"format": "outro"}'),
      throwsA(isA<AppFailure>()),
    );
  });
}
