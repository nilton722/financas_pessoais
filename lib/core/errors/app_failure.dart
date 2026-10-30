/// Falha esperada da aplicação. A mensagem destina-se à interface e nunca
/// contém valores, descrições ou identificadores financeiros.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure: $message';
}
