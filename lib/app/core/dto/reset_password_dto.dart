// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

class ResetPasswordDto {
  final String newPassword;
  final String token; // Changed from code to token for link-based reset
  final String email;

  ResetPasswordDto(this.newPassword, this.token, this.email);

  Map<String, dynamic> toMap() {
    return {'newPassword': newPassword, 'token': token, 'email': email};
  }
}
