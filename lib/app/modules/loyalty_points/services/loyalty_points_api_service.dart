import 'package:get_it/get_it.dart';
import '../../../core/api_service/loyalty_points/loyalty_points_api_service.dart'
    as core;

class LoyaltyPointsApiService {
  final core.LoyaltyPointsApiService _loyaltyPointsApiService =
      GetIt.I.get<core.LoyaltyPointsApiService>();

  Future<int> getUserLoyaltyPoints() async {
    try {
      return await _loyaltyPointsApiService.getUserLoyaltyPoints();
    } catch (e) {
      throw Exception('Error fetching loyalty points: $e');
    }
  }
}
