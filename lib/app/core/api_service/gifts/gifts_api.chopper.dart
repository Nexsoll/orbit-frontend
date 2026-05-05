// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'gifts_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$GiftsApi extends GiftsApi {
  _$GiftsApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = GiftsApi;

  @override
  Future<Response<dynamic>> getGifts() {
    final Uri $url = Uri.parse('gifts/');
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
