// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'loyalty_points_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$LoyaltyPointsApi extends LoyaltyPointsApi {
  _$LoyaltyPointsApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = LoyaltyPointsApi;

  @override
  Future<Response<dynamic>> getUserLoyaltyPoints() {
    final Uri $url = Uri.parse('loyalty-points/');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
