import 'dart:convert';

import 'package:financas_pessoais/core/backup/backup_crypto.dart';
import 'package:financas_pessoais/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const passphrase = 'frase-de-teste-2026';
  const payload =
      '{"format":"financas_pessoais_backup","settings":{"locale":"pt_PT"},'
      '"description":"Mercado · pão \\"quente\\""}';

  Map<String, dynamic> envelopeOf(String value) =>
      jsonDecode(value) as Map<String, dynamic>;

  test('cifra e decifra o mesmo JSON sem alterar acentos', () async {
    final envelope = await encryptBackup(
      payload,
      passphrase,
      iterations: 100000,
    );
    expect(isEncryptedBackup(envelope), isTrue);
    expect(envelope.contains('Mercado'), isFalse);
    final document = envelopeOf(envelope);
    expect(document['format'], encryptedBackupFormat);
    expect(document['formatVersion'], encryptedBackupFormatVersion);
    expect(document['cipher'], encryptedBackupCipher);
    expect(document['kdf'], encryptedBackupKdf);

    final clear = await decryptBackup(envelope, passphrase);
    expect(clear, payload);
  });

  test('usa sal e nonce diferentes em cada ficheiro', () async {
    final first = envelopeOf(
      await encryptBackup(payload, passphrase, iterations: 100000),
    );
    final second = envelopeOf(
      await encryptBackup(payload, passphrase, iterations: 100000),
    );
    expect(first['salt'], isNot(second['salt']));
    expect(first['nonce'], isNot(second['nonce']));
    expect(first['ciphertext'], isNot(second['ciphertext']));
  });

  test('rejeita frase-passe curta ao criar', () async {
    await expectLater(
      encryptBackup(payload, 'curta'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('pelo menos 8'),
        ),
      ),
    );
  });

  test('frase-passe errada não decifra e não expõe dados', () async {
    final envelope = await encryptBackup(
      payload,
      passphrase,
      iterations: 100000,
    );
    await expectLater(
      decryptBackup(envelope, 'outra-frase-2026'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          'Frase-passe incorreta ou ficheiro alterado.',
        ),
      ),
    );
  });

  test('deteta ciphertext, MAC e cabeçalho adulterados', () async {
    final envelope = await encryptBackup(
      payload,
      passphrase,
      iterations: 100000,
    );

    Future<void> expectTampered(Map<String, dynamic> document) async {
      await expectLater(
        decryptBackup(jsonEncode(document), passphrase),
        throwsA(isA<AppFailure>()),
      );
    }

    final ciphertext = envelopeOf(envelope);
    final ciphertextBytes = base64Decode(ciphertext['ciphertext'] as String);
    ciphertextBytes[0] ^= 0x01;
    ciphertext['ciphertext'] = base64Encode(ciphertextBytes);
    await expectTampered(ciphertext);

    final mac = envelopeOf(envelope);
    final macBytes = base64Decode(mac['mac'] as String);
    macBytes[0] ^= 0x01;
    mac['mac'] = base64Encode(macBytes);
    await expectTampered(mac);

    final header = envelopeOf(envelope)
      ..['iterations'] = 100001; // muda a chave derivada
    await expectTampered(header);
  });

  test('rejeita envelopes incompletos ou com parâmetros inválidos', () async {
    final valid = envelopeOf(
      await encryptBackup(payload, passphrase, iterations: 100000),
    );

    Future<void> expectInvalid(Map<String, dynamic> document) async {
      await expectLater(
        decryptBackup(jsonEncode(document), passphrase),
        throwsA(isA<AppFailure>()),
      );
    }

    await expectInvalid(Map<String, dynamic>.from(valid)..remove('salt'));
    await expectInvalid(
      Map<String, dynamic>.from(valid)..['salt'] = base64Encode([1, 2, 3]),
    );
    await expectInvalid(
      Map<String, dynamic>.from(valid)..['iterations'] = 1000,
    );
    await expectInvalid(
      Map<String, dynamic>.from(valid)..['formatVersion'] = 2,
    );
    await expectInvalid(
      Map<String, dynamic>.from(valid)..['cipher'] = 'AES-128-CBC',
    );

    await expectLater(
      decryptBackup('{ isto não é json', passphrase),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      decryptBackup('{"format":"outra_coisa"}', passphrase),
      throwsA(isA<AppFailure>()),
    );
  });

  test('distingue backups simples de cifrados', () {
    expect(isEncryptedBackup(payload), isFalse);
    expect(isEncryptedBackup('{ isto não é json'), isFalse);
    expect(isEncryptedBackup('{"format":"$encryptedBackupFormat"}'), isTrue);
  });
}
