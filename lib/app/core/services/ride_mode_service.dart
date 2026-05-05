class RideModeService {
  RideModeService._();
  static final RideModeService instance = RideModeService._();

  bool isDriverMode = false;

  void setDriverMode(bool isDriver) {
    isDriverMode = isDriver;
  }
}
