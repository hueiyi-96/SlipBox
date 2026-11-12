class TracePayConfig {
  const TracePayConfig({required this.apiBaseUrl, this.apiToken});

  /// Worker origin. Local development uses `wrangler dev`.
  /// The public origin is https://api.tracepay.app once DNS is on Cloudflare.
  final String apiBaseUrl;

  /// Bearer token sent to the Worker. Leave empty until `.dev.vars` has API_TOKEN.
  final String? apiToken;

  static const local = TracePayConfig(apiBaseUrl: 'http://127.0.0.1:8787');
}
