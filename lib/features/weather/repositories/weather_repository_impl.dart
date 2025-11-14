import '../models/weather_model.dart';
import '../data/weather_data_source.dart';
import '../repositories/weather_repository.dart';

/// Implementasi konkret dari WeatherRepository
class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherDataSource _dataSource;

  WeatherRepositoryImpl({WeatherDataSource? dataSource})
      : _dataSource = dataSource ?? WeatherDataSource();

  @override
  Future<WeatherModel?> getWeather(String location) async {
    return _dataSource.getCurrentWeather(location);
  }

  @override
  Future<WeatherModel?> getWeatherWithForecast(String location, {int days = 3}) async {
    return _dataSource.getWeatherWithForecast(location, days: days);
  }

  @override
  Future<List<String>> searchLocation(String query) async {
    return _dataSource.searchLocation(query);
  }
}

