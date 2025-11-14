import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

/// Data source untuk Weather API
/// Menangani komunikasi dengan Weather API
class WeatherDataSource {
  static const String apiKey = '25a3290c78a145c893401610253010';
  static const String baseUrl = 'https://api.weatherapi.com/v1';

  /// Mengambil data cuaca saat ini
  Future<WeatherModel?> getCurrentWeather(String location) async {
    try {
      final url = Uri.parse(
        '$baseUrl/current.json?key=$apiKey&q=$location&lang=id',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return WeatherModel.fromJsonCurrent(jsonData);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil data cuaca dengan forecast
  Future<WeatherModel?> getWeatherWithForecast(String location, {int days = 3}) async {
    try {
      if (days < 1) days = 1;
      if (days > 3) days = 3; // batas free plan

      final url = Uri.parse(
        '$baseUrl/forecast.json?key=$apiKey&q=$location&days=$days&lang=id',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return WeatherModel.fromJson(jsonData);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mencari lokasi berdasarkan kata kunci
  Future<List<String>> searchLocation(String query) async {
    try {
      if (query.isEmpty) {
        return [];
      }
      
      final url = Uri.parse(
        '$baseUrl/search.json?key=$apiKey&q=$query',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as List;
        return jsonData
            .map((item) => item['name'] as String)
            .toList()
            .cast<String>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}

