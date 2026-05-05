import 'package:flutter/material.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

class ChatColorService {
  ChatColorService._();
  static final ChatColorService I = ChatColorService._();

  static const Color defaultBrown = Color(0xFFB48648);

  String _roomKey(String roomId) => 'chat_color_room_$roomId';
  String _peerKey(String peerId) => 'chat_color_peer_$peerId';

  /// Get color for a specific room. Falls back to peer color, then default brown.
  Color getColorForRoom(String roomId, String? peerId) {
    final prefs = VChatController.I.sharedPreferences;
    
    // Try room-specific color first
    final roomColorValue = prefs.getInt(_roomKey(roomId));
    if (roomColorValue != null) {
      return Color(roomColorValue);
    }

    // Try peer-specific color (for single chats)
    if (peerId != null) {
      final peerColorValue = prefs.getInt(_peerKey(peerId));
      if (peerColorValue != null) {
        return Color(peerColorValue);
      }
    }

    // Default brown
    return defaultBrown;
  }

  /// Set color for a specific room
  Future<void> setColorForRoom(String roomId, Color color) async {
    final prefs = VChatController.I.sharedPreferences;
    await prefs.setInt(_roomKey(roomId), color.value);
    // Notify listeners
    VEventBusSingleton.vEventBus.fire(VUpdateRoomColorEvent(roomId: roomId));
  }

  /// Set color for a peer (affects all single chats with this peer)
  Future<void> setColorForPeer(String peerId, Color color) async {
    final prefs = VChatController.I.sharedPreferences;
    await prefs.setInt(_peerKey(peerId), color.value);
  }

  /// Reset to default color
  Future<void> resetToDefault(String roomId, String? peerId) async {
    final prefs = VChatController.I.sharedPreferences;
    await prefs.remove(_roomKey(roomId));
    if (peerId != null) {
      await prefs.remove(_peerKey(peerId));
    }
    VEventBusSingleton.vEventBus.fire(VUpdateRoomColorEvent(roomId: roomId));
  }

  /// Predefined color palette
  static const List<Color> colorPalette = [
    Color(0xFFB48648), // Default brown
    Color(0xFFE57373), // Red
    Color(0xFFBA68C8), // Purple
    Color(0xFF64B5F6), // Blue
    Color(0xFF4DB6AC), // Teal
    Color(0xFF81C784), // Green
    Color(0xFFFFD54F), // Amber
    Color(0xFFFF8A65), // Deep Orange
    Color(0xFF90A4AE), // Blue Grey
    Color(0xFFA1887F), // Brown
    Color(0xFFEF5350), // Bright Red
    Color(0xFFAB47BC), // Bright Purple
    Color(0xFF42A5F5), // Bright Blue
    Color(0xFF26A69A), // Bright Teal
    Color(0xFF66BB6A), // Bright Green
    Color(0xFFFFCA28), // Bright Amber
  ];
}
