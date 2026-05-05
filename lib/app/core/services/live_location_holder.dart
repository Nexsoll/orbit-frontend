// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

/// Helper class to hold pending live location duration between
/// the attachment selection and location submission
class LiveLocationHolder {
  static int? _pendingDuration;

  /// Set the duration for the next location share
  static void setDuration(int minutes) {
    _pendingDuration = minutes;
  }

  /// Get and clear the pending duration
  static int? takeDuration() {
    final duration = _pendingDuration;
    _pendingDuration = null;
    return duration;
  }

  /// Check if there's a pending live location duration
  static bool get hasPendingDuration => _pendingDuration != null;

  /// Clear any pending duration
  static void clear() {
    _pendingDuration = null;
  }
}
