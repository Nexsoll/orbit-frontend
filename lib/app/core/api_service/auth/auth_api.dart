// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';

part 'auth_api.chopper.dart';

@ChopperApi(baseUrl: 'auth')
abstract class AuthApi extends ChopperService {
  @Post(path: "/login")
  Future<Response> login(@Body() Map<String, dynamic> body);

  @Post(path: "/two-factor/verify")
  Future<Response> twoFactorVerify(@Body() Map<String, dynamic> body);

  ///send-otp-register
  @Post(path: "/send-otp-register")
  Future<Response> sendOtpRegister(@Body() Map<String, dynamic> body);

  ///verify-otp-register
  @Post(path: "/verify-otp-register")
  Future<Response> verifyOtpRegister(@Body() Map<String, dynamic> body);

  ///send-link-register
  @Post(path: "/send-link-register")
  Future<Response> sendLinkRegister(@Body() Map<String, dynamic> body);

  ///verify-link-register
  @Post(path: "/verify-link-register")
  Future<Response> verifyLinkRegister(@Body() Map<String, dynamic> body);

  ///send-link-reset-password
  @Post(path: "/send-link-reset-password")
  Future<Response> sendOtpResetPassword(@Body() Map<String, dynamic> body);

  ///verify-and-reset-password
  @Post(path: "/verify-and-reset-password")
  Future<Response> verifyAndResetPassword(@Body() Map<String, dynamic> body);

  @Post(path: "/register")
  @multipart
  Future<Response> register(
    @PartMap() List<PartValue> body,
    @PartFile("file") MultipartFile? file,
  );

  @Post(path: "/auth0")
  Future<Response> auth0Login(@Body() Map<String, dynamic> body);

  @Post(path: "/logout")
  Future<Response> logout(@Body() Map<String, dynamic> body);

  /// Firebase Phone Auth - Register
  @Post(path: "/firebase-phone-register")
  Future<Response> firebasePhoneRegister(@Body() Map<String, dynamic> body);

  /// Firebase Phone Auth - Login
  @Post(path: "/firebase-phone-login")
  Future<Response> firebasePhoneLogin(@Body() Map<String, dynamic> body);

  static AuthApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: SConstants.sApiBaseUrl,
      services: [
        _$AuthApi(),
      ],
      converter: const JsonConverter(),
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()..connectionTimeout = const Duration(seconds: 7),
            ),
    );
    return _$AuthApi(client);
  }
}
