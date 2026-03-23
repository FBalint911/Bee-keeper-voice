import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Megjegyzés: Ha Android emulátort használsz, a localhost címe: 10.0.2.2
  // Ha saját telefont, akkor a géped belső IP címe kell!
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<bool> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return response.statusCode == 200;
  }

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return response.statusCode == 200;
  }
}