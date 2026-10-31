import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashFinished extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

/// Fica verdadeiro quando o splash já desvaneceu e a aplicação está revelada.
///
/// O pedido de desbloqueio espera por este sinal para não aparecer por cima do
/// splash de arranque.
final splashFinishedProvider = NotifierProvider<SplashFinished, bool>(
  SplashFinished.new,
);
