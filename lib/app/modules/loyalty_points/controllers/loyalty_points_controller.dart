import 'package:super_up_core/super_up_core.dart';
import '../services/loyalty_points_api_service.dart';

class LoyaltyPointsController extends SLoadingController<int> {
  final LoyaltyPointsApiService _apiService = LoyaltyPointsApiService();

  LoyaltyPointsController() : super(SLoadingState(0));

  @override
  void onInit() {
    getLoyaltyPoints();
  }

  @override
  void onClose() {}

  Future<void> getLoyaltyPoints() async {
    await vSafeApiCall<int>(
      onLoading: () async {
        setStateLoading();
      },
      onError: (exception, trace) {
        setStateError(exception.toString());
      },
      request: () async {
        return _apiService.getUserLoyaltyPoints();
      },
      onSuccess: (points) {
        value.data = points;
        setStateSuccess();
      },
      ignoreTimeoutAndNoInternet: false,
    );
  }
}
