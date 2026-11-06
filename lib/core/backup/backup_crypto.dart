import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../errors/app_failure.dart';

/// Envelope cifrado para backups. O JSON original é autenticado e cifrado com
/// AES-256-GCM; a chave deriva da frase-passe com PBKDF2-HMAC-SHA256 e um sal
/// aleatório por ficheiro. Os parâmetros ficam no envelope para permitir
/// restaurar noutro dispositivo, mas qualquer alteração ao cabeçalho invalida
/// a autenticação.
const String encryptedBackupFormat = 'financas_pessoais_backup_encrypted';
const int encryptedBackupFormatVersion = 1;
const String encryptedBackupCipher = 'AES-256-GCM';
const String encryptedBackupKdf = 'PBKDF2-HMAC-SHA256';

/// Custo do PBKDF2. Equilibra a resistência a tentativas offline com o tempo
/// de abertura num telefone; ver docs/DECISIONS.md (ADR-045).
const int encryptedBackupKdfIterations = 210000;
const int minimumBackupPassphraseLength = 8;

const int _saltLengthBytes = 16;
const int _nonceLengthBytes = 12;
const int _macLengthBytes = 16;
const int _minAcceptedIterations = 100000;
const int _maxAcceptedIterations = 1000000;

/// Indica, sem decifrar, se o conteúdo tem o envelope de backup cifrado.
/// Um ficheiro ilegível ou de outro formato devolve `false`; a validação
/// completa acontece no restauro.
bool isEncryptedBackup(String contents) {
  try {
    final decoded = jsonDecode(contents);
    return decoded is Map<String, dynamic> &&
        decoded['format'] == encryptedBackupFormat;
  } on FormatException {
    return false;
  }
}

/// Cifra um backup JSON já validado. A frase-passe não é guardada.
///
/// [iterations] existe apenas para testes de custo; a aplicação usa o valor
/// por omissão. Valores fora do intervalo aceite são rejeitados.
Future<String> encryptBackup(
  String plaintextJson,
  String passphrase, {
  int iterations = encryptedBackupKdfIterations,
}) async {
  _validatePassphrase(passphrase);
  _validateIterations(iterations);
  final salt = _randomBytes(_saltLengthBytes);
  final nonce = _randomBytes(_nonceLengthBytes);
  final header = _header(iterations: iterations, salt: salt, nonce: nonce);
  final key = await _deriveKey(passphrase, salt, iterations);
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(plaintextJson),
    secretKey: key,
    nonce: nonce,
    aad: utf8.encode(header),
  );
  final envelope = <String, Object?>{
    'format': encryptedBackupFormat,
    'formatVersion': encryptedBackupFormatVersion,
    'cipher': encryptedBackupCipher,
    'kdf': encryptedBackupKdf,
    'iterations': iterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  };
  return const JsonEncoder.withIndent('  ').convert(envelope);
}

/// Decifra um envelope criado por [encryptBackup] e devolve o JSON original.
/// Uma frase errada, um cabeçalho alterado ou um ficheiro truncado produzem a
/// mesma mensagem, para não revelar qual dos casos falhou.
Future<String> decryptBackup(String contents, String passphrase) async {
  final Map<String, Object?> envelope;
  try {
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const AppFailure('O ficheiro não é um backup cifrado válido.');
    }
    envelope = Map<String, Object?>.from(decoded);
  } on FormatException {
    throw const AppFailure('O ficheiro não é um backup JSON válido.');
  }

  if (envelope['format'] != encryptedBackupFormat) {
    throw const AppFailure(
      'O ficheiro não é um backup cifrado desta aplicação.',
    );
  }
  final formatVersion = envelope['formatVersion'];
  if (formatVersion is! int || formatVersion < 1) {
    throw const AppFailure('O backup cifrado não indica uma versão válida.');
  }
  if (formatVersion > encryptedBackupFormatVersion) {
    throw const AppFailure(
      'O backup cifrado foi criado por uma versão mais recente da aplicação.',
    );
  }
  if (envelope['cipher'] != encryptedBackupCipher) {
    throw const AppFailure('O backup cifrado usa uma cifra não suportada.');
  }
  if (envelope['kdf'] != encryptedBackupKdf) {
    throw const AppFailure(
      'O backup cifrado usa um método de chave não suportado.',
    );
  }
  final iterations = envelope['iterations'];
  if (iterations is! int) {
    throw const AppFailure('O backup cifrado tem parâmetros inválidos.');
  }
  _validateIterations(iterations);
  final salt = _decodeField(envelope['salt'], _saltLengthBytes);
  final nonce = _decodeField(envelope['nonce'], _nonceLengthBytes);
  final mac = _decodeField(envelope['mac'], _macLengthBytes);
  final ciphertext = _decodeField(envelope['ciphertext'], null);
  if (ciphertext.isEmpty) {
    throw const AppFailure('O backup cifrado está vazio ou incompleto.');
  }
  if (passphrase.isEmpty) {
    throw const AppFailure('Escreva a frase-passe do backup.');
  }

  final key = await _deriveKey(passphrase, salt, iterations);
  try {
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
      aad: utf8.encode(
        _header(iterations: iterations, salt: salt, nonce: nonce),
      ),
    );
    return utf8.decode(clear);
  } on SecretBoxAuthenticationError {
    throw const AppFailure('Frase-passe incorreta ou ficheiro alterado.');
  }
}

Future<SecretKey> _deriveKey(
  String passphrase,
  List<int> salt,
  int iterations,
) {
  final kdf = Pbkdf2.hmacSha256(iterations: iterations, bits: 256);
  return kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
}

String _header({
  required int iterations,
  required List<int> salt,
  required List<int> nonce,
}) => [
  encryptedBackupFormat,
  '$encryptedBackupFormatVersion',
  encryptedBackupCipher,
  encryptedBackupKdf,
  '$iterations',
  base64Encode(salt),
  base64Encode(nonce),
].join('\n');

List<int> _decodeField(Object? value, int? expectedLength) {
  if (value is! String || value.isEmpty) {
    throw const AppFailure('O backup cifrado está incompleto.');
  }
  final List<int> bytes;
  try {
    bytes = base64Decode(value);
  } on FormatException {
    throw const AppFailure('O backup cifrado tem dados inválidos.');
  }
  if (expectedLength != null && bytes.length != expectedLength) {
    throw const AppFailure('O backup cifrado tem parâmetros inválidos.');
  }
  return bytes;
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

void _validatePassphrase(String passphrase) {
  if (passphrase.runes.length < minimumBackupPassphraseLength) {
    throw const AppFailure(
      'A frase-passe deve ter pelo menos '
      '$minimumBackupPassphraseLength caracteres.',
    );
  }
}

void _validateIterations(int iterations) {
  if (iterations < _minAcceptedIterations ||
      iterations > _maxAcceptedIterations) {
    throw const AppFailure('O backup cifrado tem parâmetros inválidos.');
  }
}
