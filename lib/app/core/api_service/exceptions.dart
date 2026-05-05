// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class SuperHttpBadRequest implements Exception {
  final Object exception;
  final StackTrace? stack;

  SuperHttpBadRequest({
    required this.exception,
    this.stack,
  });

  @override
  String toString() {
    return exception.toString();
  }
}

class VChatHttpUnAuth implements Exception {
  final Object exception;
  final StackTrace? stack;

  VChatHttpUnAuth({
    required this.exception,
    this.stack,
  });

  @override
  String toString() {
    return exception.toString();
  }
}
