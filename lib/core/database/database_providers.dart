import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'app_database_opener.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(openAppDatabase());
  ref.onDispose(database.close);
  return database;
});
