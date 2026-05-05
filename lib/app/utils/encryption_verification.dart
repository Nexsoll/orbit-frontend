// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Utility class for generating safety numbers and key fingerprints for encryption verification
class EncryptionVerification {
  /// Generates a 60-digit safety number from two user identifiers
  /// Similar to Signal's safety number implementation
  static String generateSafetyNumber(String currentUserId, String otherUserId) {
    // Ensure consistent ordering regardless of who initiates verification
    final sortedIds = [currentUserId, otherUserId]..sort();
    final combinedId = '${sortedIds[0]}:${sortedIds[1]}';
    
    // Add a salt to make it more secure and unique to this app
    final saltedData = 'SuperUpSafetyNumber2024:$combinedId';
    
    // Generate SHA-256 hash
    final bytes = utf8.encode(saltedData);
    final digest = sha256.convert(bytes);
    
    // Convert hash to safety number
    return _hashToSafetyNumber(digest.bytes);
  }
  
  /// Generates a shorter verification code (12 digits) for easier comparison
  static String generateVerificationCode(String currentUserId, String otherUserId) {
    final safetyNumber = generateSafetyNumber(currentUserId, otherUserId);
    // Take first 12 digits for easier verbal verification
    return safetyNumber.substring(0, 12);
  }
  
  /// Converts hash bytes to a 60-digit safety number
  static String _hashToSafetyNumber(List<int> hashBytes) {
    final buffer = StringBuffer();
    
    // Convert each byte to a 2-digit number and concatenate
    for (int i = 0; i < hashBytes.length && buffer.length < 60; i++) {
      final byte = hashBytes[i];
      // Convert byte (0-255) to 2-digit string (00-99)
      final twoDigits = (byte % 100).toString().padLeft(2, '0');
      buffer.write(twoDigits);
    }
    
    // Ensure exactly 60 digits
    final result = buffer.toString();
    return result.length >= 60 ? result.substring(0, 60) : result.padRight(60, '0');
  }
  
  /// Formats safety number with spaces for better readability
  /// Example: "12345 67890 12345 67890 12345 67890"
  static String formatSafetyNumber(String safetyNumber) {
    final buffer = StringBuffer();
    for (int i = 0; i < safetyNumber.length; i += 5) {
      if (i > 0) buffer.write(' ');
      final end = (i + 5 < safetyNumber.length) ? i + 5 : safetyNumber.length;
      buffer.write(safetyNumber.substring(i, end));
    }
    return buffer.toString();
  }
  
  /// Formats verification code with spaces for better readability
  /// Example: "1234 5678 9012"
  static String formatVerificationCode(String code) {
    final buffer = StringBuffer();
    for (int i = 0; i < code.length; i += 4) {
      if (i > 0) buffer.write(' ');
      final end = (i + 4 < code.length) ? i + 4 : code.length;
      buffer.write(code.substring(i, end));
    }
    return buffer.toString();
  }
  
  /// Validates if two safety numbers match
  static bool verifySafetyNumbers(String number1, String number2) {
    // Remove spaces and compare
    final clean1 = number1.replaceAll(' ', '');
    final clean2 = number2.replaceAll(' ', '');
    return clean1 == clean2;
  }
}
