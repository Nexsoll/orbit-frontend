// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'user_files_api.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: type=lint
final class _$UserFilesApi extends UserFilesApi {
  _$UserFilesApi([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final Type definitionType = UserFilesApi;

  @override
  Future<Response<dynamic>> getUserFiles({
    int? page,
    int? limit,
    String? fileType,
  }) {
    final Uri $url = Uri.parse('user/files');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'fileType': fileType,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> getPrivateMedia({
    int? page,
    int? limit,
    String? fileType,
  }) {
    final Uri $url = Uri.parse('user/files/private-media');
    final Map<String, dynamic> $params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'fileType': fileType,
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      parameters: $params,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteFile(String fileId) {
    final Uri $url = Uri.parse('user/files/${fileId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deletePrivateMedia(String fileId) {
    final Uri $url = Uri.parse('user/files/private-media/${fileId}');
    final Request $request = Request(
      'DELETE',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> deleteMultipleFiles(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('user/files');
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
  Future<Response<dynamic>> deleteMultiplePrivateMedia(
      Map<String, dynamic> body) {
    final Uri $url = Uri.parse('user/files/private-media');
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
  Future<Response<dynamic>> cleanupOrphanedFiles() {
    final Uri $url = Uri.parse('user/files/cleanup');
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> uploadFiles(MultipartFile file) {
    final Uri $url = Uri.parse('user/files/upload');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile>(
        'file',
        file,
      )
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> uploadPrivateMedia(MultipartFile file) {
    final Uri $url = Uri.parse('user/files/private-media/upload');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile>(
        'file',
        file,
      )
    ];
    final Request $request = Request(
      'POST',
      $url,
      client.baseUrl,
      parts: $parts,
      multipart: true,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> testEndpoint(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('user/files/test');
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
  Future<Response<dynamic>> uploadSimple(Map<String, dynamic> body) {
    final Uri $url = Uri.parse('user/files/upload-simple');
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
  Future<Response<dynamic>> uploadAny(MultipartFile file) {
    final Uri $url = Uri.parse('user/files/upload-any');
    final List<PartValue> $parts = <PartValue>[
      PartValueFile<MultipartFile>(
        'file',
        file,
      )
    ];
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
