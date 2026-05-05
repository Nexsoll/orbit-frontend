// Stub implementation for non-web platforms

Future<String> loginWithSocialProviderWeb(String connection) async {
  throw UnsupportedError('Auth0Web is only supported on web platforms');
}

Future<void> logoutWeb() async {
  throw UnsupportedError('Auth0Web is only supported on web platforms');
}

Future<void> handleWebCallback() async {
  // No-op on non-web platforms
}
