// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'profile_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$ProfileApi extends ProfileApi {
  _$ProfileApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = ProfileApi;

  @override
  Future<Response<dynamic>> updateImage(MultipartFile file) {
    final Uri $url = Uri.parse('profile/image');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile>(
        'file',
        file,
      )
    ];
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> checkVersion(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/version');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUserName(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/name');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updatePassword(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/password');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUserBio(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/bio');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUserPhoneNumber(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/phone-number');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUserGender(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/gender');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUserProfession(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/profession');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateDateOfBirth(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/date-of-birth');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateLocation(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/location');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> setVisit() {
    final Uri $url = Uri.parse('profile/visit');
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> createReport(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/report');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> device() {
    final Uri $url = Uri.parse('profile/device');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updatePrivacy(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/privacy');
    final $body = body;
    final Request $request = Request(
      'PATCH',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> adminNotifications(Map<String, dynamic> query) {
    final Uri $url = Uri.parse('profile/admin-notifications');
    final Map<String, dynamic> $params = query;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteDevice(
    String id,
    Map<String, dynamic> body,
  ) {
    final Uri $url = Uri.parse('profile/device/${id}');
    final $body = body;
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteMyAccount(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/delete-my-account');
    final $body = body;
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> myBlocked(Map<String, dynamic> query) {
    final Uri $url = Uri.parse('profile/blocked');
    final Map<String, dynamic> $params = query;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> myProfile() {
    final Uri $url = Uri.parse('profile/');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> passwordCheck(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/password-check');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> peerProfile(String id) {
    final Uri $url = Uri.parse('profile/${id}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> publicProfile(String id) {
    final Uri $url = Uri.parse('profile/public/${id}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> appConfig() {
    final Uri $url = Uri.parse('profile/app-config');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getTwoFactorStatus() {
    final Uri $url = Uri.parse('profile/two-factor');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> requestTwoFactor() {
    final Uri $url = Uri.parse('profile/two-factor/request');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> enableTwoFactor(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/two-factor/enable');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> disableTwoFactor(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/two-factor/disable');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> appUsers(Map<String, dynamic> query) {
    final Uri $url = Uri.parse('profile/users');
    final Map<String, dynamic> $params = query;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getUserLoyaltyPoints() {
    final Uri $url = Uri.parse('profile/loyalty-points');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getBalance() {
    final Uri $url = Uri.parse('profile/balance');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> addToBalance(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/balance/add');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> subtractFromBalance(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/balance/subtract');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> claimGift(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/gifts/claim');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> isGiftClaimed(String giftMessageId) {
    final Uri $url = Uri.parse('profile/gifts/claimed/${giftMessageId}');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> sendMoney(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/send-money');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> createVerificationRequest(
      Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/verification/requests');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMyLatestVerificationRequest() {
    final Uri $url = Uri.parse('profile/verification/requests/my-latest');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> createAd(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('profile/ads');
    final $body = body;
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      body: $body,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getApprovedAds(int limit) {
    final Uri $url = Uri.parse('profile/ads/approved');
    final Map<String, dynamic> $params = <String, dynamic>{'limit': limit};
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getMyAds(Map<String, dynamic> query) {
    final Uri $url = Uri.parse('profile/ads/my');
    final Map<String, dynamic> $params = query;
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
