// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:super_up_core/super_up_core.dart';

import 'exceptions.dart';

class ErrorInterceptor implements ErrorConverter {
  @override
  FutureOr<Response> convertError<BodyType, InnerType>(Response response) {
    Map<String, dynamic> errorMap;
    try {
      errorMap = jsonDecode(response.body.toString()) as Map<String, dynamic>;
    } catch (_) {
      final bodyStr = response.body?.toString() ?? '';
      final preview = bodyStr.length > 200 ? bodyStr.substring(0, 200) : bodyStr;
      errorMap = {
        'data': 'Server returned non-JSON error (status ${response.statusCode}). $preview'
      };
    }

    return response.copyWith(
      bodyError: errorMap,
      body: errorMap,
    );
  }
}

void throwIfNotSuccess(Response res) {
  if (res.isSuccessful) return;

  Map<String, dynamic>? err;
  final raw = res.error ?? res.body;
  if (raw is Map<String, dynamic>) {
    err = raw;
  }
  final msg = (err?['data'] ?? 'Request failed').toString();
  if (res.statusCode == 400) {
    throw SuperHttpBadRequest(
      exception: msg,
    );
  } else if (res.statusCode == 404) {
    throw SuperHttpBadRequest(
      exception: msg,
    );
  } else if (res.statusCode == 403) {
    throw SuperHttpBadRequest(
      exception: msg,
    );
  } else if (res.statusCode == 450) {
    unAuthStream450Error.add(true);
    throw VChatHttpUnAuth(
      exception: msg,
    );
  }
  if (!res.isSuccessful) {
    throw SuperHttpBadRequest(
      exception: msg,
    );
  }
}

Map<String, dynamic> extractDataFromResponse(Response res) {
  return (res.body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
}

class AuthInterceptor implements Interceptor {
  final String? access;

  AuthInterceptor({
    this.access,
  });

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    // Try to resolve token safely; if SharedPreferences is not initialized yet
    // (e.g., Safari/web race at startup), skip adding the header instead of throwing.
    String? token = access;
    if (token == null) {
      try {
        token = VAppPref.getHashedString(
          key: SStorageKeys.vAccessToken.name,
        );
      } catch (_) {
        // Ignore preference access errors at startup
      }
    }

    final request = (token != null && token.isNotEmpty)
        ? applyHeader(
            chain.request,
            'authorization',
            'Bearer $token',
          )
        : chain.request;

    return chain.proceed(request);
  }
}
