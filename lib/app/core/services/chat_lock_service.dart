// Copyright 2025, Orbit chat.
// Local chat lock service: stores a single app-level password hash and a list of locked room IDs.

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class ChatLockService {
  ChatLockService._();
  static final ChatLockService instance = ChatLockService._();

  static const _kHashKey = 'chat_lock_hash';
  static const _kSaltKey = 'chat_lock_salt';
  static const _kLockedRoomsKey = 'locked_rooms_ids';

  bool get isPasswordSet {
    final prefs = VChatController.I.sharedPreferences;
    return (prefs.getString(_kHashKey) ?? '').isNotEmpty &&
        (prefs.getString(_kSaltKey) ?? '').isNotEmpty;
  }

  Future<void> setPassword(String password) async {
    final salt = _randomSalt();
    final hash = _hash(password, salt);
    final prefs = VChatController.I.sharedPreferences;
    await prefs.setString(_kSaltKey, salt);
    await prefs.setString(_kHashKey, hash);
  }

  bool verifyPassword(String password) {
    final prefs = VChatController.I.sharedPreferences;
    final salt = prefs.getString(_kSaltKey);
    final stored = prefs.getString(_kHashKey);
    if (salt == null || stored == null) return false;
    final h = _hash(password, salt);
    return h == stored;
  }

  // Room locks
  List<String> get lockedRooms {
    final prefs = VChatController.I.sharedPreferences;
    return prefs.getStringList(_kLockedRoomsKey) ?? const <String>[];
  }

  bool isRoomLocked(String roomId) => lockedRooms.contains(roomId);

  Future<void> lockRoom(String roomId) async {
    final prefs = VChatController.I.sharedPreferences;
    final l = lockedRooms.toList();
    if (!l.contains(roomId)) {
      l.add(roomId);
      await prefs.setStringList(_kLockedRoomsKey, l);
    }
  }

  Future<void> unlockRoom(String roomId) async {
    final prefs = VChatController.I.sharedPreferences;
    final l = lockedRooms.toList();
    if (l.contains(roomId)) {
      l.remove(roomId);
      await prefs.setStringList(_kLockedRoomsKey, l);
    }
  }

  // Helpers
  String _randomSalt([int length = 16]) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => alphabet[rand.nextInt(alphabet.length)]).join();
  }

  String _hash(String password, String salt) {
    final data = utf8.encode('$salt:$password');
    return sha256.convert(data).toString();
  }
}
