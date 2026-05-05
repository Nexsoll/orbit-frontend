import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'dart:js' as js;
import 'dart:html' as html;
import 'auth0_config.dart';
import 'package:super_up_core/super_up_core.dart';

bool isAuth0Available() {
  try {
    return js.context.hasProperty('auth0') && 
           js.context['auth0'] != null &&
           js.context['auth0'].hasProperty('createAuth0Client');
  } catch (e) {
    return false;
  }
}

Auth0Web createAuth0Web(String domain, String clientId) => Auth0Web(domain, clientId);

Future<String> loginWithSocialProviderWeb(String connection) async {
  print('🔐 Web platform detected, checking Auth0 script...');
  
  // Check if Auth0 script is loaded
  bool auth0Available = isAuth0Available();
  
  if (!auth0Available) {
    print('🔐 Auth0 SPA JS not available, waiting...');
    // Wait up to 3 seconds for Auth0 to load
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (isAuth0Available()) {
        auth0Available = true;
        break;
      }
    }
  }
  
  if (!auth0Available) {
    throw Exception('Auth0 SPA JS library not loaded. Please refresh the page.');
  }
  
  print('🔐 Auth0 script confirmed available, creating client...');
  
  // Use loginWithRedirect instead of popup for better compatibility
  final auth0Web = createAuth0Web(Auth0Config.domain, Auth0Config.clientId);
  print('🔐 Auth0Web instance created with domain: ${Auth0Config.domain}');
  
  // Check if user is already logged in
  try {
    final existingCreds = await auth0Web.credentials();
    if (existingCreds.accessToken.isNotEmpty) {
      print('🔐 User already logged in, using existing token');
      return existingCreds.accessToken;
    }
  } catch (e) {
    print('🔐 No existing credentials, proceeding with login');
  }
  
  print('🔐 Calling loginWithRedirect for connection: $connection');
  await auth0Web.loginWithRedirect(
    redirectUrl: '${Uri.base.origin}',
    scopes: {'openid', 'profile', 'email'},
    parameters: {
      'connection': connection,
    },
  );
  
  // This won't be reached as redirect will happen
  throw Exception('Login redirect initiated');
}

Future<void> logoutWeb() async {
  final auth0Web = createAuth0Web(Auth0Config.domain, Auth0Config.clientId);
  await auth0Web.logout();
}

Future<void> handleWebCallback() async {
  try {
    await Future.delayed(const Duration(milliseconds: 500)); // Wait for app to initialize
    final auth0Web = createAuth0Web(Auth0Config.domain, Auth0Config.clientId);
    final creds = await auth0Web.onLoad();
    if (creds != null && creds.accessToken.isNotEmpty) {
      print('🔐 Auth0 callback detected, user logged in');
      // Persist access token so Splash can complete backend login automatically
      await VAppPref.setHashedString(
        SStorageKeys.pendingAuth0AccessToken.name,
        creds.accessToken,
      );
      // Clean the URL (remove auth query params)
      try {
        final cleanUrl = Uri.base.origin + Uri.base.path;
        html.window.history.replaceState(null, '', cleanUrl);
      } catch (e) {
        // ignore URL cleanup errors
      }
    }
  } catch (e) {
    print('🔐 No Auth0 callback or error: $e');
  }
}
