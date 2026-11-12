import 'config.dart';

Map<String, String> apiHeaders(TracePayConfig config, {String? contentType}) {
  final token = config.apiToken;
  return {
    'content-type': ?contentType,
    if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
  };
}
