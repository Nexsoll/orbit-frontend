class CurrentRoomHolder {
  static String? _roomId;
  static void set(String roomId) => _roomId = roomId;
  static String? get id => _roomId;
}
