import "dart:convert";
import "package:firebase_auth/firebase_auth.dart";
import "package:http/http.dart" as http;

/// HTTP client for all calls to the WorkGo Render backend.
/// All requests automatically include the current user"s Firebase ID token.
class WorkGoApiClient {
  static final WorkGoApiClient _instance = WorkGoApiClient._();
  factory WorkGoApiClient() => _instance;
  WorkGoApiClient._();

  // Set via dart-define: --dart-define=RENDER_BASE_URL=https://workgo-api.onrender.com
  static const String _baseUrl = String.fromEnvironment(
    "RENDER_BASE_URL",
    defaultValue: "https://workgo-api.onrender.com",
  );

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<dynamic> get(String path) async {
    final resp = await http.get(
      Uri.parse("$_baseUrl$path"),
      headers: await _headers(),
    );
    return _parse(resp);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse("$_baseUrl$path"),
      headers: await _headers(),
      body: json.encode(body),
    );
    return _parse(resp);
  }

  dynamic _parse(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return json.decode(resp.body);
    }
    throw Exception("API ${resp.statusCode}: ${resp.body}");
  }
}
