import 'package:super_up/app/core/api_service/status_ai/status_ai_api.dart';
import 'package:super_up/app/core/api_service/story/story_api.dart';
import 'package:super_up/app/core/models/story/status_ai_models.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:http/http.dart' show MultipartFile;

import '../interceptors.dart';

class StatusAiApiService {
  static StatusAiApi? _api;

  StatusAiApiService._();

  Future<StatusAiCaptionResult> generateCaption(StatusAiCaptionDto dto) async {
    final res = await _api!.generateCaption(dto.toMap());
    throwIfNotSuccess(res);
    return StatusAiCaptionResult.fromMap(extractDataFromResponse(res));
  }

  Future<StatusAiAnalysisResult> analyze(StatusAiAnalyzeDto dto) async {
    final res = await _api!.analyze(dto.toMap());
    throwIfNotSuccess(res);
    return StatusAiAnalysisResult.fromMap(extractDataFromResponse(res));
  }

  Future<StatusAiSuggestionResult> getSuggestions(
    StatusAiSuggestionsDto dto, {
    VPlatformFile? mediaFile,
  }) async {
    MultipartFile? multipartFile;
    if (mediaFile != null) {
      multipartFile = await VPlatforms.getMultipartFile(source: mediaFile);
    }
    final res = await _api!.getSuggestions(dto.toListOfPartValue(), multipartFile);
    throwIfNotSuccess(res);
    return StatusAiSuggestionResult.fromMap(extractDataFromResponse(res));
  }

  static StatusAiApiService init({
    Uri? baseUrl,
    String? accessToken,
  }) {
    _api = StatusAiApi.create(
      accessToken: accessToken,
      baseUrl: baseUrl ?? StoryApi.storyReelsServiceBaseUrl,
    );
    return StatusAiApiService._();
  }
}
