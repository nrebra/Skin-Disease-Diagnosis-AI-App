import 'package:http/http.dart' as http;

void testApiConnection() async {
  try {
    final String baseUrl =
        'https://ebr39fr.sayar.com/api'; // Define your base URL here
    final response = await http.get(Uri.parse('$baseUrl/test'));
    print('API Connection: ${response.statusCode}');
  } catch (e) {
    print('API Connection Error: $e');
  }
}
