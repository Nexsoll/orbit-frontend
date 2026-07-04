import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' hide Response, Request;
import 'package:http/io_client.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../interceptors.dart';
import '../safe_json_converter.dart';
import '../story/story_api.dart';

part 'status_ai_api.chopper.dart';

@ChopperApi(baseUrl: 'status-ai')
abstract class StatusAiApi extends ChopperService {
  @Post(path: "/caption")
  Future<Response> generateCaption(
    @Body() Map<String, dynamic> body,
  );

  @Post(path: "/analyze")
  Future<Response> analyze(
    @Body() Map<String, dynamic> body,
  );

  @Post(path: "/suggestions")
  @multipart
  Future<Response> getSuggestions(
    @PartMap() List<PartValue> body,
    @PartFile("file") MultipartFile? file,
  );

  static StatusAiApi create({
    Uri? baseUrl,
    String? accessToken,
  }) {
    final client = ChopperClient(
      baseUrl: baseUrl ?? StoryApi.storyReelsServiceBaseUrl,
      services: [
        _$StatusAiApi(),
      ],
      converter: const SafeJsonConverter(),
      interceptors: [AuthInterceptor()],
      errorConverter: ErrorInterceptor(),
      client: VPlatforms.isWeb
          ? null
          : IOClient(
              HttpClient()
                ..connectionTimeout = const Duration(seconds: 30)
                ..connectionTimeout = const Duration(minutes: 10),
            ),
    );
    return _$StatusAiApi(client);
  }
}
