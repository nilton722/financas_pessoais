import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef AppFilesRootResolver = Future<Directory> Function();

/// Pasta de dados acessível ao utilizador para exportações e backups.
///
/// No Android usa a pasta externa específica da aplicação
/// (`Android/data/<pacote>/files`), que não exige permissões de armazenamento
/// e pode ser copiada por USB ou por um gestor de ficheiros. No desktop usa a
/// pasta de documentos. O resolvedor é injetável para testes.
class AppFiles {
  AppFiles({AppFilesRootResolver? rootResolver})
    : _rootResolver = rootResolver ?? _defaultRoot;

  static const String backupsFolder = 'backups';
  static const String exportsFolder = 'exports';

  final AppFilesRootResolver _rootResolver;

  static Future<Directory> _defaultRoot() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        return external;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> root() async {
    final directory = await _rootResolver();
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> folder(String name) async {
    final base = await root();
    final directory = Directory('${base.path}${Platform.pathSeparator}$name');
    await directory.create(recursive: true);
    return directory;
  }
}
