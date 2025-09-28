import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:4300/api/survivor';

  static Future<LoginResponse> login(String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/login');

      final body = json.encode({
        'email': email,
        'password': password,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return LoginResponse.fromJson(jsonData);
      } else {
        throw Exception('Error en login: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<Survivor>> getAllSurvivors() async {
    try {
      final url = Uri.parse(baseUrl);

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Survivor.fromJson(json)).toList();
      } else {
        throw Exception('Error obteniendo ligas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> joinSurvivor(String userId, String survivorId) async {
    try {
      final url = Uri.parse('$baseUrl/join/$survivorId');

      final body = json.encode({'userId': userId});

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Error uni|ndose a liga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> makePick({
    required String userId,
    required String survivorId,
    required String matchId,
    required String predictedTeamId,
    required int week,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/pick');

      final body = json.encode({
        'userId': userId,
        'survivorId': survivorId,
        'matchId': matchId,
        'predictedTeamId': predictedTeamId,
        'week': week,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Error haciendo pick: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> getLeaderboard(String survivorId) async {
    try {
      final url = Uri.parse('$baseUrl/leaderboard/$survivorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo leaderboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<dynamic>> getPredictions(String survivorId) async {
    try {
      final url = Uri.parse('$baseUrl/predictions/$survivorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo predictions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<List<dynamic>> getGambles(String survivorId) async {
    try {
      final url = Uri.parse('$baseUrl/gambles/$survivorId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo gambles: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserInfo(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/user/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo info del usuario: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> logout(String userId) async {
    try {
      final url = Uri.parse('$baseUrl/logout');

      final body = json.encode({'userId': userId});

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error en logout: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> processWeek() async {
    try {
      final url = Uri.parse('http://localhost:4300/api/simulation/run-week');

      final body = json.encode({
        'loggedUserId': '1'
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error procesando semana: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<Map<String, dynamic>> getResults(String survivorId) async {
    try {
      final url = Uri.parse('$baseUrl/results/$survivorId');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo resultados: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}