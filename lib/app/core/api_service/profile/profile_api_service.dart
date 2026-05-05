// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:chopper/chopper.dart';
import 'package:super_up/app/core/api_service/profile/profile_api.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';
import 'package:v_platform/v_platform.dart';

import '../../../modules/home/settings_modules/my_account/views/sheet_for_update_password.dart';
import '../../../modules/peer_profile/states/peer_profile_state.dart';
import '../../dto/create_report_dto.dart';
import '../../models/user_device_model.dart';
import '../interceptors.dart';
import 'dart:developer';

class ProfileApiService {
  static ProfileApi? _profileApi;

  ProfileApiService._();

  Future<String> updateImage(VPlatformFile img) async {
    final res = await _profileApi!.updateImage(
      await VPlatforms.getMultipartFile(
        source: img,
      ),
    );
    throwIfNotSuccess(res);
    return res.body['data'] as String;
  }

  // ===================== Ads =====================
  Future<Map<String, dynamic>> createAd({
    required String title,
    required String imageUrl,
    String? linkUrl,
  }) async {
    final res = await _profileApi!.createAd({
      'title': title,
      'imageUrl': imageUrl,
      if (linkUrl != null) 'linkUrl': linkUrl,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // Paid Ad Submission (M-Pesa STK)
  Future<Map<String, dynamic>> initiateAdSubmission({
    required String title,
    required String imageUrl,
    String? linkUrl,
    required String phone,
  }) async {
    final client = _profileApi!.client;
    final req = Request(
      'POST',
      Uri.parse('profile/ads/submit/initiate'),
      client.baseUrl,
      body: {
        'title': title,
        'imageUrl': imageUrl,
        if (linkUrl != null) 'linkUrl': linkUrl,
        'phone': phone,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> getAdSubmissionStatus(
      String submissionId) async {
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('profile/ads/submissions/$submissionId/status'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // Wallet-based ad submission (deducts from balance)
  Future<Map<String, dynamic>> submitAdWithWallet({
    required String title,
    required String imageUrl,
    String? linkUrl,
  }) async {
    final client = _profileApi!.client;
    final req = Request(
      'POST',
      Uri.parse('profile/ads/submit/wallet'),
      client.baseUrl,
      body: {
        'title': title,
        'imageUrl': imageUrl,
        if (linkUrl != null) 'linkUrl': linkUrl,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<List<Map<String, dynamic>>> getApprovedAds({int limit = 10}) async {
    final res = await _profileApi!.getApprovedAds(limit);
    throwIfNotSuccess(res);
    final body = res.body as Map<String, dynamic>;
    final data = body['data'] as List? ?? const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> getMyAds({int page = 1, int limit = 20}) async {
    final res = await _profileApi!.getMyAds({
      'page': page,
      'limit': limit,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<void> updatePassword(UpdatePasswordDto dto) async {
    final res = await _profileApi!.updatePassword(dto.toMap());
    throwIfNotSuccess(res);
  }

  Future<SVersion> checkVersion(String current) async {
    final res = await _profileApi!.checkVersion({"semVer": current});
    throwIfNotSuccess(res);
    return SVersion.fromMap(extractDataFromResponse(res));
  }

  Future<bool> setVisit() async {
    final res = await _profileApi!.setVisit();
    throwIfNotSuccess(res);
    return true;
  }

  Future<bool> createReport(CreateReportDto data) async {
    final res = await _profileApi!.createReport(data.toMap());
    throwIfNotSuccess(res);
    return true;
  }

  Future<bool> deleteDevice(String id, String password) async {
    final res = await _profileApi!.deleteDevice(
      id,
      {"password": password},
    );
    throwIfNotSuccess(res);
    return true;
  }

  Future<bool> deleteMyAccount(String password) async {
    final res = await _profileApi!.deleteMyAccount(
      {"password": password},
    );
    throwIfNotSuccess(res);
    return true;
  }

  Future<List<UserDeviceModel>> getMyDevices() async {
    final res = await _profileApi!.device();
    throwIfNotSuccess(res);
    final l = (res.body as Map<String, dynamic>)['data'] as List;
    return l.map((e) => UserDeviceModel.fromMap(e)).toList();
  }

  Future<List<SBaseUser>> getMyBlocked({
    VBaseFilter? filter,
  }) async {
    final res = await _profileApi!.myBlocked(filter?.toMap() ?? {});
    throwIfNotSuccess(res);
    final l = (res.body as Map<String, dynamic>)['data']['docs'] as List;
    return l.map((e) => SBaseUser.fromMap(e['targetId'])).toList();
  }

  Future<bool> updatePrivacy(UserPrivacy userPrivacy) async {
    final res = await _profileApi!.updatePrivacy(userPrivacy.toMap());
    throwIfNotSuccess(res);
    return true;
  }

  Future<List<AdminNotificationsModel>> getMyAdminNotifications({
    VBaseFilter? filter,
  }) async {
    final res = await _profileApi!.adminNotifications(filter?.toMap() ?? {});
    throwIfNotSuccess(res);
    final l = (res.body as Map<String, dynamic>)['data']['docs'] as List;
    return l.map((e) => AdminNotificationsModel.fromMap(e)).toList();
  }

  Future<bool> updateUserBio(String bio) async {
    final res = await _profileApi!.updateUserBio({"bio": bio});
    throwIfNotSuccess(res);

    return true;
  }

  Future<bool> updateUserPhoneNumber(String phoneNumber) async {
    final res =
        await _profileApi!.updateUserPhoneNumber({"phoneNumber": phoneNumber});
    throwIfNotSuccess(res);

    return true;
  }

  Future<bool> updateUserGender(String gender) async {
    final res = await _profileApi!.updateUserGender({"gender": gender});
    throwIfNotSuccess(res);

    return true;
  }

  Future<bool> updateUserProfession(String profession) async {
    final res =
        await _profileApi!.updateUserProfession({"profession": profession});
    throwIfNotSuccess(res);
    return true;
  }

  Future<bool> updateLocation(
      {required double latitude, required double longitude}) async {
    try {
      log('Updating location to: $latitude, $longitude');
      final res = await _profileApi!.updateLocation({
        'latitude': latitude,
        'longitude': longitude,
        'myUser': {
          '_id':
              'temp_id', // This will be replaced by the backend with the actual user ID from the auth token
        },
      });
      log('Location update response: ${res.body}');
      throwIfNotSuccess(res);
      return true;
    } catch (e, stack) {
      log('Error updating location', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<bool> updateUserName(String fullName) async {
    final res = await _profileApi!.updateUserName({"fullName": fullName});
    throwIfNotSuccess(res);

    return true;
  }

  Future<SMyProfile> getMyProfile() async {
    final res = await _profileApi!.myProfile();
    throwIfNotSuccess(res);
    return SMyProfile.fromMap(extractDataFromResponse(res));
  }

  Future<Map<String, int>> getFollowCounts(String userId) async {
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('user-follow/$userId/counts'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    final data =
        (res.body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return {
      'followers': (data['followersCount'] as num?)?.toInt() ?? 0,
      'following': (data['followingCount'] as num?)?.toInt() ?? 0,
    };
  }

  Future<bool> passwordCheck(String password) async {
    final res = await _profileApi!.passwordCheck({"password": password});
    throwIfNotSuccess(res);
    return true;
  }

  Future<String> resolvePhoneToUserId(String phone) async {
    final v = phone.toString().trim();
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('profile/resolve-phone'),
      client.baseUrl,
      parameters: {
        'phone': v,
      },
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    final data =
        (res.body as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return (data['userId'] ?? '').toString();
  }

  Future<PeerProfileModel> peerProfile(String peerId) async {
    final res = await _profileApi!.peerProfile(peerId);
    throwIfNotSuccess(res);
    print('Raw API Response: ${res.body}');
    final data = res.body['data'] as Map<String, dynamic>;
    print('Parsed data: $data');
    print('MutualGroups in response: ${data['mutualGroups']}');
    return PeerProfileModel.fromMap(data);
  }

  Future<String> followUser(String peerId) async {
    final client = _profileApi!.client;
    final req = Request(
      'POST',
      Uri.parse('user-follow/$peerId/follow'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return (res.body as Map<String, dynamic>)['data'].toString();
  }

  Future<String> unfollowUser(String peerId) async {
    final client = _profileApi!.client;
    final req = Request(
      'POST',
      Uri.parse('user-follow/$peerId/unfollow'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return (res.body as Map<String, dynamic>)['data'].toString();
  }

  Future<List<SBaseUser>> getFollowers(
    String userId, {
    VBaseFilter? filter,
  }) async {
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('user-follow/$userId/followers'),
      client.baseUrl,
      parameters: filter?.toMap() ?? {},
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    final docs =
        ((res.body as Map<String, dynamic>)['data']['docs'] as List?) ??
            const [];
    return docs
        .map((e) => SBaseUser.fromMap(
            (e as Map<String, dynamic>)['followerId'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<SBaseUser>> getFollowing(
    String userId, {
    VBaseFilter? filter,
  }) async {
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('user-follow/$userId/following'),
      client.baseUrl,
      parameters: filter?.toMap() ?? {},
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    final docs =
        ((res.body as Map<String, dynamic>)['data']['docs'] as List?) ??
            const [];
    return docs
        .map((e) => SBaseUser.fromMap(
            (e as Map<String, dynamic>)['followingId'] as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> publicProfile(String peerId) async {
    final res = await _profileApi!.publicProfile(peerId);
    throwIfNotSuccess(res);
    return res.body['data'] as Map<String, dynamic>;
  }

  Future<bool> checkIsFollowing(String peerId) async {
    final client = _profileApi!.client;
    final req = Request(
      'GET',
      Uri.parse('user-follow/$peerId/follow'),
      client.baseUrl,
    );
    final res = await client.send(req);
    throwIfNotSuccess(res);
    return (res.body as Map<String, dynamic>)['data'] as bool;
  }

  // ================= Two-Factor Authentication (Email) =================
  Future<bool> getTwoFactorStatusEnabled() async {
    final res = await _profileApi!.getTwoFactorStatus();
    throwIfNotSuccess(res);
    final data = extractDataFromResponse(res);
    return (data['enabled'] == true);
  }

  Future<void> requestTwoFactor() async {
    final res = await _profileApi!.requestTwoFactor();
    throwIfNotSuccess(res);
  }

  Future<void> enableTwoFactor(String code) async {
    final res = await _profileApi!.enableTwoFactor({'code': code});
    throwIfNotSuccess(res);
  }

  Future<void> disableTwoFactor(String code) async {
    final res = await _profileApi!.disableTwoFactor({'code': code});
    throwIfNotSuccess(res);
  }

  Future<UserPrivacyType> getPeerGroupAddPermission(String peerId) async {
    final res = await _profileApi!.peerProfile(peerId);
    throwIfNotSuccess(res);
    final data = res.body['data'] as Map<String, dynamic>;
    final up = data['userPrivacy'] as Map<String, dynamic>?;
    final s = up?['groupAddPermission'] as String?;
    if (s == null) return UserPrivacyType.public;
    try {
      return UserPrivacyType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => UserPrivacyType.public,
      );
    } catch (_) {
      return UserPrivacyType.public;
    }
  }

  Future<AppConfigModel> appConfig() async {
    final res = await _profileApi!.appConfig();
    throwIfNotSuccess(res);
    return AppConfigModel.fromMap(res.body['data'] as Map<String, dynamic>);
  }

  Future<List<SSearchUser>> appUsers(UserFilterDto dto) async {
    log('----Sending filter DTO: ${dto.toMap()}');
    final res = await _profileApi!.appUsers(dto.toMap());

    log('----app users------${res}');
    throwIfNotSuccess(res);
    return (extractDataFromResponse(res)['users'] as List)
        .map(
          (e) => SSearchUser.fromMap(e),
        )
        .toList();
  }

  Future<Response> getUserLoyaltyPoints() async {
    final res = await _profileApi!.getUserLoyaltyPoints();
    throwIfNotSuccess(res);
    return res;
  }

  // Balance management methods
  Future<Map<String, dynamic>> getBalance() async {
    final res = await _profileApi!.getBalance();
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> addToBalance(double amount) async {
    final res = await _profileApi!.addToBalance({'amount': amount});
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> subtractFromBalance(double amount) async {
    final res = await _profileApi!.subtractFromBalance({'amount': amount});
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // Claimed gifts management methods
  Future<Map<String, dynamic>> claimGift(
      String giftMessageId, double amount) async {
    final res = await _profileApi!.claimGift({
      'giftMessageId': giftMessageId,
      'amount': amount,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> isGiftClaimed(String giftMessageId) async {
    final res = await _profileApi!.isGiftClaimed(giftMessageId);
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>> sendMoney({
    required String receiverId,
    required num amount,
  }) async {
    final res = await _profileApi!.sendMoney({
      'receiverId': receiverId,
      'amount': amount,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  // Verification request methods
  Future<Map<String, dynamic>> createVerificationRequest({
    required String idImageUrl,
    required String selfieImageUrl,
    String? paymentReference,
    String? paymentScreenshotUrl,
    String? feePlan,
  }) async {
    final res = await _profileApi!.createVerificationRequest({
      'idImageUrl': idImageUrl,
      'selfieImageUrl': selfieImageUrl,
      if (paymentReference != null) 'paymentReference': paymentReference,
      if (paymentScreenshotUrl != null)
        'paymentScreenshotUrl': paymentScreenshotUrl,
      if (feePlan != null) 'feePlan': feePlan,
    });
    throwIfNotSuccess(res);
    return extractDataFromResponse(res);
  }

  Future<Map<String, dynamic>?> getMyLatestVerificationRequest() async {
    final res = await _profileApi!.getMyLatestVerificationRequest();
    throwIfNotSuccess(res);
    final body = res.body as Map<String, dynamic>;
    final data = body['data'];
    if (data == null) return null;
    return data as Map<String, dynamic>;
  }

  static ProfileApiService init({
    Uri? baseUrl,
    String? accessToken,
  }) {
    log('------you base url ----- ${baseUrl}');
    _profileApi ??= ProfileApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? SConstants.sApiBaseUrl,
    );
    return ProfileApiService._();
  }
}
