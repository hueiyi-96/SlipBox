import 'config.dart';

Map<String, String> apiHeaders(
  TracePayConfig config, {
  String? contentType,
}) {
  return {
    if (contentType != null) 'content-type': contentType,
    if (config.apiToken != null && config.apiToken!.isNotEmpty)
      'authorization': 'Bearer ${config.apiToken}',
  };
}
