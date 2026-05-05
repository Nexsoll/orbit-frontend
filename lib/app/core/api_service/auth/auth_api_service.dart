// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:chopper/chopper.dart';
import 'package:super_up/app/core/api_service/auth/auth_api.dart';
import 'package:super_up/app/core/api_service/interceptors.dart';
import 'package:super_up/app/core/dto/reset_password_dto.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:http/http.dart' show MultipartFile;
import 'package:v_platform/v_platform.dart';

class AuthApiService {
  static AuthApi? _authApi;

  AuthApiService._();

  static AuthApiService init({Uri? baseUrl, String? accessToken}) {
    _authApi ??= AuthApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? SConstants.sApiBaseUrl,
    );
    return AuthApiService._();
  }

  Future<Map<String, dynamic>> login(LoginDto dto) async {
    final Response res = await _authApi!.login(dto.toMap());
    throwIfNotSuccess(res);
    final body = res.body as Map<String, dynamic>;
    await _saveAccessTokenFromBody(body);
    return body;
  }

  Future<void> verifyLoginPassword(LoginDto dto) async {
    final Response res = await _authApi!.login(dto.toMap());
    throwIfNotSuccess(res);
  }

  Future<void> twoFactorVerify(Map<String, dynamic> body) async {
    final Response res = await _authApi!.twoFactorVerify(body);
    throwIfNotSuccess(res);
    await _saveAccessTokenFromBody(res.body as Map<String, dynamic>);
  }

  Future<void> auth0Login(Map<String, dynamic> body) async {
    final Response res = await _authApi!.auth0Login(body);
    throwIfNotSuccess(res);
    await _saveAccessTokenFromBody(res.body as Map<String, dynamic>);
  }

  Future<void> sendResetPasswordEmailOtp(String email) async {
    final Response res = await _authApi!.sendOtpResetPassword({
      'email': email,
    });
    throwIfNotSuccess(res);
  }

  Future<void> verifyAndResetPassword(ResetPasswordDto dto) async {
    final Response res = await _authApi!.verifyAndResetPassword(dto.toMap());
    throwIfNotSuccess(res);
  }

  Future<void> sendOtpRegister(String email) async {
    final Response res = await _authApi!.sendOtpRegister({'email': email});
    throwIfNotSuccess(res);
  }

  Future<void> verifyOtpRegister({required String email, required String code}) async {
    final Response res = await _authApi!.verifyOtpRegister({'email': email, 'code': code});
    throwIfNotSuccess(res);
  }

  Future<void> sendLinkRegister(
    String email,
    String fullName,
    String password, {
    String? profession,
    RegisterMethod method = RegisterMethod.email,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'fullName': fullName,
      'password': password,
      'method': method.name,
    };

    final p = profession?.trim();
    if (p != null && p.isNotEmpty) {
      body['profession'] = p;
    }

    final Response res = await _authApi!.sendLinkRegister(body);
    throwIfNotSuccess(res);
  }

  Future<void> verifyLinkRegister({required String email, required String token}) async {
    final Response res = await _authApi!.verifyLinkRegister({'email': email, 'token': token});
    throwIfNotSuccess(res);
  }

  Future<void> register(RegisterDto dto, {VPlatformFile? image}) async {
    MultipartFile? file;
    if (image != null) {
      file = await VPlatforms.getMultipartFile(source: image);
    }
    final Response res = await _authApi!.register(dto.toListOfPartValue(), file);
    throwIfNotSuccess(res);
    await _saveAccessTokenFromBody(res.body as Map<String, dynamic>);
  }

  Future<void> _saveAccessTokenFromBody(Map<String, dynamic> body) async {
    final data = body['data'];
    String? token;
    if (data is Map<String, dynamic>) {
      token = (data['accessToken'] ?? data['token']) as String?;
    }
    token ??= body['accessToken'] as String?;
    token ??= body['token'] as String?;

    if (token != null && token.isNotEmpty) {
      await VAppPref.setHashedString(SStorageKeys.vAccessToken.name, token);
    }
  }

  /// Firebase Phone Auth - Register with ID token
  Future<Map<String, dynamic>> firebasePhoneRegister({
    required String idToken,
    required String fullName,
    required String password,
    required String deviceId,
    required String platform,
    String? profession,
    String? language,
    Map<String, dynamic>? deviceInfo,
    String? pushKey,
  }) async {
    final body = <String, dynamic>{
      'idToken': idToken,
      'fullName': fullName,
      'password': password,
      'deviceId': deviceId,
      'platform': platform,
    };

    final p = profession?.trim();
    if (p != null && p.isNotEmpty) {
      body['profession'] = p;
    }
    if (language != null) {
      body['language'] = language;
    }
    if (deviceInfo != null) {
      body['deviceInfo'] = deviceInfo;
    }
    if (pushKey != null) {
      body['pushKey'] = pushKey;
    }

    final Response res = await _authApi!.firebasePhoneRegister(body);
    throwIfNotSuccess(res);
    final responseBody = res.body as Map<String, dynamic>;
    await _saveAccessTokenFromBody(responseBody);
    return responseBody;
  }

  /// Firebase Phone Auth - Login with ID token
  Future<Map<String, dynamic>> firebasePhoneLogin({
    required String idToken,
    required String password,
    required String deviceId,
    required String platform,
    String? language,
    Map<String, dynamic>? deviceInfo,
    String? pushKey,
  }) async {
    final body = <String, dynamic>{
      'idToken': idToken,
      'password': password,
      'deviceId': deviceId,
      'platform': platform,
    };

    if (language != null) {
      body['language'] = language;
    }
    if (deviceInfo != null) {
      body['deviceInfo'] = deviceInfo;
    }
    if (pushKey != null) {
      body['pushKey'] = pushKey;
    }

    final Response res = await _authApi!.firebasePhoneLogin(body);
    throwIfNotSuccess(res);
    final responseBody = res.body as Map<String, dynamic>;
    await _saveAccessTokenFromBody(responseBody);
    return responseBody;
  }
}

