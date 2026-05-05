// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';

part 'profile_api.chopper.dart';

@ChopperApi(baseUrl: 'profile')
abstract class ProfileApi extends ChopperService {
  ///update image
  @Patch(path: '/image')
  @multipart
  Future<Response> updateImage(
    @PartFile("file") MultipartFile file,
  );

  @Patch(path: '/version')
  Future<Response> checkVersion(@Body() Map<String, dynamic> body);

  ///update name
  @Patch(path: "/name")
  Future<Response> updateUserName(@Body() Map<String, dynamic> body);

  @Patch(path: "/password")
  Future<Response> updatePassword(@Body() Map<String, dynamic> body);

  ///update name
  @Patch(path: "/bio")
  Future<Response> updateUserBio(@Body() Map<String, dynamic> body);

  ///update phone number
  @Patch(path: "/phone-number")
  Future<Response> updateUserPhoneNumber(@Body() Map<String, dynamic> body);

  ///update gender
  @Patch(path: "/gender")
  Future<Response> updateUserGender(@Body() Map<String, dynamic> body);

  ///update profession
  @Patch(path: "/profession")
  Future<Response> updateUserProfession(@Body() Map<String, dynamic> body);

  /// update location
  @Patch(path: "/location")
  Future<Response> updateLocation(@Body() Map<String, dynamic> body);

  @Patch(path: "/visit", optionalBody: true)
  Future<Response> setVisit();

  @Post(path: "/report")
  Future<Response> createReport(@Body() Map<String, dynamic> body);

  @Get(path: "/device")
  Future<Response> device();
  @Patch(path: "/privacy")
  Future<Response> updatePrivacy(
    @Body() Map<String, dynamic> body,
  );
  @Get(path: "/admin-notifications")
  Future<Response> adminNotifications(
    @QueryMap() Map<String, dynamic> query,
  );

  @Delete(path: "/device/{id}")
  Future<Response> deleteDevice(
    @Path("id") String id,
    @Body() Map<String, dynamic> body,
  );

  @Delete(path: "/delete-my-account")
  Future<Response> deleteMyAccount(
    @Body() Map<String, dynamic> body,
  );

  @Get(path: "/blocked")
  Future<Response> myBlocked(
    @QueryMap() Map<String, dynamic> query,
  );

  @Get(path: "/")
  Future<Response> myProfile();

  @Post(path: "/password-check")
  Future<Response> passwordCheck(@Body() Map<String, dynamic> body);

  @Get(path: "/{id}")
  Future<Response> peerProfile(@Path("id") String id);

  @Get(path: "/public/{id}")
  Future<Response> publicProfile(@Path("id") String id);

  @Get(path: "/app-config")
  Future<Response> appConfig();

  // Two-Factor Authentication (Email)
  @Get(path: "/two-factor")
  Future<Response> getTwoFactorStatus();

  @Post(path: "/two-factor/request")
  Future<Response> requestTwoFactor();

  @Post(path: "/two-factor/enable")
  Future<Response> enableTwoFactor(@Body() Map<String, dynamic> body);

  @Post(path: "/two-factor/disable")
  Future<Response> disableTwoFactor(@Body() Map<String, dynamic> body);

  @Get(path: "/users")
  Future<Response> appUsers(
    @QueryMap() Map<String, dynamic> query,
  );

  @GET(path: "/loyalty-points")
  Future<Response> getUserLoyaltyPoints();

  // Balance endpoints
  @GET(path: "/balance")
  Future<Response> getBalance();

  @POST(path: "/balance/add")
  Future<Response> addToBalance(@Body() Map<String, dynamic> body);

  @POST(path: "/balance/subtract")
  Future<Response> subtractFromBalance(@Body() Map<String, dynamic> body);

  // Claimed gifts endpoints
  @POST(path: "/gifts/claim")
  Future<Response> claimGift(@Body() Map<String, dynamic> body);

  @GET(path: "/gifts/claimed/{giftMessageId}")
  Future<Response> isGiftClaimed(@Path() String giftMessageId);

  @POST(path: "/send-money")
  Future<Response> sendMoney(@Body() Map<String, dynamic> body);

  // Verification endpoints
  @POST(path: "/verification/requests")
  Future<Response> createVerificationRequest(@Body() Map<String, dynamic> body);

  @GET(path: "/verification/requests/my-latest")
  Future<Response> getMyLatestVerificationRequest();

  // Ads endpoints
  @POST(path: "/ads")
  Future<Response> createAd(@Body() Map<String, dynamic> body);

  @GET(path: "/ads/approved")
  Future<Response> getApprovedAds(@Query("limit") int limit);

  @GET(path: "/ads/my")
  Future<Response> getMyAds(@QueryMap() Map<String, dynamic> query);

  static ProfileApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: SConstants.sApiBaseUrl,
      services: [
        _$ProfileApi(),
      ],
      converter: const JsonConverter(),
      //, HttpLoggingInterceptor()
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()..connectionTimeout = const Duration(seconds: 10),
            ),
    );
    return _$ProfileApi(client);
  }
}
