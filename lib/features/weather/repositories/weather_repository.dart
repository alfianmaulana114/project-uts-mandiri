import '../models/weather_model.dart';

/// Abstraksi repository untuk pengelolaan data Weather
abstract class WeatherRepository {
  /// Mengambil data cuaca saat ini
  Future<WeatherModel?> getWeather(String location);

  /// Mengambil data cuaca dengan forecast
  Future<WeatherModel?> getWeatherWithForecast(String location, {int days = 3});

  /// Mencari lokasi berdasarkan kata kunci
  Future<List<String>> searchLocation(String query);
}

