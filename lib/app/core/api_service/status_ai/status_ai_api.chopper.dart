// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'status_ai_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$StatusAiApi extends StatusAiApi {
  _$StatusAiApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = StatusAiApi;

  @override
  Future<Response<dynamic>> generateCaption(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('status-ai/caption');
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
  Future<Response<dynamic>> analyze(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('status-ai/analyze');
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
  Future<Response<dynamic>> getSuggestions(
    List<PartValue<dynamic>> body,
    MultipartFile? file,
  ) {
    final Uri $url = Uri.parse('status-ai/suggestions');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile?>(
        'file',
        file,
      )
    ];
    $parts.addAll(body);
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
