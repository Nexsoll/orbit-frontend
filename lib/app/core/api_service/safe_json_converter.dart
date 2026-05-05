// A tolerant JSON converter for Chopper that avoids throwing FormatException
// when the server returns non-JSON (e.g. HTML error pages). Falls back to the
// raw response body string when JSON decoding fails.
import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart';

class SafeJsonConverter extends JsonConverter {
  const SafeJsonConverter();

  @override
  Request convertRequest(Request request) {
    final contentType = request.headers['content-type'] ?? '';
    if ((request.body is Map || request.body is List) &&
        !contentType.contains('application/json')) {
      final encoded = json.encode(request.body);
      return request.copyWith(
        body: encoded,
        headers: {
          ...request.headers,
          'content-type': 'application/json',
        },
      );
    }
    return super.convertRequest(request);
  }

  @override
  FutureOr<Response<ResultType>> convertResponse<ResultType, Item>(
    Response response,
  ) {
    try {
      return super.convertResponse<ResultType, Item>(response);
    } catch (_) {
      // If JSON parsing fails (e.g., HTML error page), keep the raw body
      final raw = response.body?.toString();
      return response.copyWith<ResultType>(body: raw as ResultType);
    }
  }
}
