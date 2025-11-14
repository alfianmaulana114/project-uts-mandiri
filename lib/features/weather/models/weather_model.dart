/// Model untuk data cuaca
/// Menyimpan informasi cuaca dari API
class WeatherModel {
  final String location;
  final double temperature;
  final String condition;
  final String icon;
  final double humidity;
  final double windSpeed;
  final String windDir; // ex: N, NE
  final double feelsLike; // feelslike_c
  final double pressureMb; // pressure_mb
  final double uv; // uv index
  final double visibilityKm; // vis_km
  final int cloud; // cloud (%)
  final double gustKph; // gust_kph
  final DateTime? lastUpdated; // current.last_updated
  final List<WeatherForecast> forecast;

  /// Konstruktor untuk membuat instance WeatherModel
  WeatherModel({
    required this.location,
    required this.temperature,
    required this.condition,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    this.windDir = '',
    this.feelsLike = 0,
    this.pressureMb = 0,
    this.uv = 0,
    this.visibilityKm = 0,
    this.cloud = 0,
    this.gustKph = 0,
    this.lastUpdated,
    required this.forecast,
  });

  /// Membuat instance WeatherModel dari JSON forecast (dengan forecast data)
  /// Untuk plan berbayar yang mendukung forecast
  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      location: json['location']['name'] as String,
      temperature: (json['current']['temp_c'] as num).toDouble(),
      condition: json['current']['condition']['text'] as String,
      icon: json['current']['condition']['icon'] as String,
      humidity: (json['current']['humidity'] as num).toDouble(),
      windSpeed: (json['current']['wind_kph'] as num).toDouble(),
      windDir: json['current']['wind_dir'] as String? ?? '',
      feelsLike: (json['current']['feelslike_c'] as num?)?.toDouble() ?? 0,
      pressureMb: (json['current']['pressure_mb'] as num?)?.toDouble() ?? 0,
      uv: (json['current']['uv'] as num?)?.toDouble() ?? 0,
      visibilityKm: (json['current']['vis_km'] as num?)?.toDouble() ?? 0,
      cloud: (json['current']['cloud'] as num?)?.toInt() ?? 0,
      gustKph: (json['current']['gust_kph'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['current']['last_updated'] != null
          ? DateTime.tryParse(json['current']['last_updated'] as String)
          : null,
      forecast: json['forecast'] != null && json['forecast']['forecastday'] != null
          ? (json['forecast']['forecastday'] as List)
              .map((day) => WeatherForecast.fromJson(day))
              .toList()
          : [],
    );
  }

  /// Membuat instance WeatherModel dari JSON current (tanpa forecast)
  /// Untuk plan free yang hanya mendukung current weather
  factory WeatherModel.fromJsonCurrent(Map<String, dynamic> json) {
    return WeatherModel(
      location: json['location']['name'] as String,
      temperature: (json['current']['temp_c'] as num).toDouble(),
      condition: json['current']['condition']['text'] as String,
      icon: json['current']['condition']['icon'] as String,
      humidity: (json['current']['humidity'] as num).toDouble(),
      windSpeed: (json['current']['wind_kph'] as num).toDouble(),
      windDir: json['current']['wind_dir'] as String? ?? '',
      feelsLike: (json['current']['feelslike_c'] as num?)?.toDouble() ?? 0,
      pressureMb: (json['current']['pressure_mb'] as num?)?.toDouble() ?? 0,
      uv: (json['current']['uv'] as num?)?.toDouble() ?? 0,
      visibilityKm: (json['current']['vis_km'] as num?)?.toDouble() ?? 0,
      cloud: (json['current']['cloud'] as num?)?.toInt() ?? 0,
      gustKph: (json['current']['gust_kph'] as num?)?.toDouble() ?? 0,
      lastUpdated: json['current']['last_updated'] != null
          ? DateTime.tryParse(json['current']['last_updated'] as String)
          : null,
      // Plan free tidak ada forecast, jadi forecast kosong
      forecast: [],
    );
  }

  /// Memeriksa apakah cuaca buruk (hujan, badai, dll)
  /// Untuk notifikasi cuaca buruk
  bool get isBadWeather {
    final conditionLower = condition.toLowerCase();
    return conditionLower.contains('rain') ||
        conditionLower.contains('storm') ||
        conditionLower.contains('thunder') ||
        conditionLower.contains('snow');
  }
}

/// Model untuk perkiraan cuaca harian
class WeatherForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final String condition;
  final String icon;

  /// Konstruktor untuk membuat instance WeatherForecast
  WeatherForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.condition,
    required this.icon,
  });

  /// Membuat instance WeatherForecast dari JSON
  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    return WeatherForecast(
      date: DateTime.parse(json['date'] as String),
      maxTemp: (json['day']['maxtemp_c'] as num).toDouble(),
      minTemp: (json['day']['mintemp_c'] as num).toDouble(),
      condition: json['day']['condition']['text'] as String,
      icon: json['day']['condition']['icon'] as String,
    );
  }
}

