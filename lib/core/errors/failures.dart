enum FailureKind {
  integrationUnavailable,
  validation,
  conflict,
  invalidCredentials,
  inactiveAccount,
  emailUnverified,
  rateLimited,
  forbidden,
  sessionExpired,
  network,
  timeout,
  server,
  storage,
  unexpected,
}

/// Safe, user-facing failure. Never include raw request/response or credentials.
class AuthFailure implements Exception {
  const AuthFailure(this.kind, this.message, {this.fieldErrors = const {}});
  final FailureKind kind;
  final String message;
  final Map<String, String> fieldErrors;
  @override
  String toString() => 'AuthFailure(${kind.name})';
}
