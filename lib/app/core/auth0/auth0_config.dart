class Auth0Config {
  static const String domain = 'dev-nt2e8s4p1khgrtwt.us.auth0.com';
  static const String clientId = 'Wq06CWAvfe2QtVS77L1lZViPvuIfd5v7';

  static const String iosScheme = 'com.superup.orbit';
  static const String androidScheme = 'com.orbit.ke';

  static String nativeScheme({required bool isAndroid}) {
    return isAndroid ? androidScheme : iosScheme;
  }
}
