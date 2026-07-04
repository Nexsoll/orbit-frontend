import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:v_platform/v_platform.dart';
import 'auth0_config.dart';

// Conditional imports for web-only functionality
import 'auth0_service_stub.dart' if (dart.library.html) 'auth0_service_web.dart'
    as auth0_web;

class AppAuth0Service {
  AppAuth0Service._();
  static final AppAuth0Service I = AppAuth0Service._();

  late final Auth0 _auth0;

  void initialize() {
    if (VPlatforms.isWeb) {
      // Handle redirect callback on app startup
      auth0_web.handleWebCallback();
    } else {
      _auth0 = Auth0(Auth0Config.domain, Auth0Config.clientId);
    }
  }

  Future<String> loginWithSocialProvider(String connection) async {
    try {
      if (VPlatforms.isWeb) {
        return await auth0_web.loginWithSocialProviderWeb(connection);
      } else {
        final result = await _auth0
            .webAuthentication(
          scheme: Auth0Config.nativeScheme(isAndroid: VPlatforms.isAndroid),
        )
            .login(
          parameters: {
            'connection': connection,
          },
        );

        if (result.accessToken.isEmpty) {
          throw Exception('Failed to get access token from Auth0');
        }

        return result.accessToken;
      }
    } catch (e) {
      throw Exception('Auth0 login failed: $e');
    }
  }

  Future<void> logout() async {
    try {
      if (VPlatforms.isWeb) {
        await auth0_web.logoutWeb();
      } else {
        await _auth0
            .webAuthentication(
              scheme: Auth0Config.nativeScheme(isAndroid: VPlatforms.isAndroid),
            )
            .logout();
      }
    } catch (e) {
      throw Exception('Auth0 logout failed: $e');
    }
  }
}
