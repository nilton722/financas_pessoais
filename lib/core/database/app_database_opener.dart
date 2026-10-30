import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_database.dart';

/// Liga a base local. `driftDatabase` resolve a pasta de dados da aplicação
/// no dispositivo e mantém o ficheiro entre arranques. O sufixo `.sqlite` é
/// acrescentado automaticamente.
QueryExecutor openAppDatabase() =>
    driftDatabase(name: AppDatabase.databaseName);
