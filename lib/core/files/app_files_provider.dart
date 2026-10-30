import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_files.dart';

/// Permite substituir a raiz das pastas. Os testes usam uma pasta temporária;
/// na aplicação fica `null` e `AppFiles` escolhe a pasta específica da app.
final appFilesRootResolverProvider = Provider<AppFilesRootResolver?>(
  (ref) => null,
);

final appFilesProvider = Provider<AppFiles>(
  (ref) => AppFiles(rootResolver: ref.watch(appFilesRootResolverProvider)),
);
