import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/repository_provider.dart';
import '../../../core/widgets/common_header.dart';
import '../../../core/widgets/common_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/weather_model.dart';

/// Halaman untuk menampilkan informasi cuaca
/// Desain mirip Notion dengan tema dark
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _repository = RepositoryProvider().weatherRepository;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  WeatherModel? _weather;
  List<WeatherForecast> _forecast = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _currentLocation = 'Jakarta';
  
  // Untuk autocomplete
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  final LayerLink _layerLink = LayerLink();

  /// Memuat data cuaca saat screen pertama kali dibuat
  @override
  void initState() {
    super.initState();
    _loadWeather(_currentLocation);
    _searchController.addListener(_onSearchChanged);
  }

  /// Listener untuk perubahan teks di search field
  /// Akan mencari suggestions saat user mengetik
  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Jika query lebih dari 1 karakter, cari suggestions
    if (query.length > 1) {
      setState(() {
        _isSearching = true;
      });

      final suggestions = await _repository.searchLocation(query);
      
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
          _isSearching = false;
        });
      }
    }
  }

  /// Mengambil data cuaca dari API untuk lokasi tertentu
  /// [location] adalah nama kota yang akan dicari cuacanya
  Future<void> _loadWeather(String location) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchSuggestions = [];
    });

    final weather = await _repository.getWeather(location);
    // Coba ambil forecast hingga 3 hari (free plan). Jika gagal, abaikan dan tetap tampilkan current.
    WeatherModel? weatherWithForecast = await _repository.getWeatherWithForecast(location, days: 3);

    setState(() {
      _isLoading = false;
      if (weather != null) {
        _weather = weatherWithForecast ?? weather;
        _forecast = (weatherWithForecast?.forecast ?? []);
        _currentLocation = location;
        _errorMessage = '';
        _searchController.clear();
        _searchFocusNode.unfocus();
        
        // Menampilkan notifikasi jika cuaca buruk
        if (weather.isBadWeather) {
          _showBadWeatherNotification(weather);
        }
      } else {
        _errorMessage = 'Gagal memuat data cuaca. Periksa koneksi internet Anda.';
      }
    });
  }

  /// Menampilkan notifikasi jika cuaca buruk terdeteksi
  /// [weather] adalah data cuaca yang berisi informasi kondisi cuaca
  void _showBadWeatherNotification(WeatherModel weather) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.textPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Peringatan: Cuaca buruk di ${weather.location} - ${weather.condition}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Mencari lokasi berdasarkan input pengguna
  /// Dipanggil saat user menekan Enter atau klik tombol search
  void _searchLocation() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _loadWeather(query);
    }
  }

  /// Membuat widget untuk menampilkan informasi cuaca saat ini
  Widget _buildCurrentWeather() {
    if (_weather == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _weather!.location,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weather!.temperature.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'C',
                    style: TextStyle(
                      fontSize: 24,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _weather!.condition,
              style: const TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_weather!.icon.isNotEmpty)
              Image.network(
                'https:${_weather!.icon}',
                width: 72,
                height: 72,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.wb_sunny,
                  size: 72,
                  color: AppTheme.accentBlue,
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildWeatherInfo(Icons.water_drop, 'Kelembapan', '${_weather!.humidity.toStringAsFixed(0)}%'),
                _buildWeatherInfo(Icons.air, 'Angin',
                    '${_weather!.windSpeed.toStringAsFixed(0)} km/j • ${_weather!.windDir.isNotEmpty ? _weather!.windDir : '-'}'),
                _buildWeatherInfo(Icons.thermostat, 'Terasa', '${_weather!.feelsLike.toStringAsFixed(0)}°C'),
                _buildWeatherInfo(Icons.visibility, 'Visibilitas', '${_weather!.visibilityKm.toStringAsFixed(1)} km'),
                _buildWeatherInfo(Icons.compress, 'Tekanan', '${_weather!.pressureMb.toStringAsFixed(0)} mb'),
                _buildWeatherInfo(Icons.wb_sunny_outlined, 'UV', _weather!.uv.toStringAsFixed(1)),
                _buildWeatherInfo(Icons.cloud_queue, 'Awan', '${_weather!.cloud}%'),
                _buildWeatherInfo(Icons.air_outlined, 'Gust', '${_weather!.gustKph.toStringAsFixed(0)} km/j'),
              ],
            ),
            if (_weather!.lastUpdated != null) ...[
              const SizedBox(height: 16),
              Text(
                'Diperbarui: ${DateFormat('dd MMM yyyy, HH:mm').format(_weather!.lastUpdated!)}',
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Section forecast 1-3 hari (free plan)
  Widget _buildForecastSection() {
    if (_forecast.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Perkiraan (3 hari)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            children: _forecast.map((f) {
              final dayName = DateFormat('EEEE', 'id_ID').format(f.date);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.divider, width: 1),
                ),
                child: Row(
                  children: [
                    if (f.icon.isNotEmpty)
                      Image.network(
                        'https:${f.icon}',
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) => const Icon(Icons.wb_sunny, color: AppTheme.accentBlue),
                      )
                    else
                      const Icon(Icons.wb_sunny, color: AppTheme.accentBlue, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayName,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            f.condition,
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${f.maxTemp.toStringAsFixed(0)}° / ${f.minTemp.toStringAsFixed(0)}°',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Membuat widget untuk menampilkan satu informasi cuaca
  /// [icon] adalah ikon yang akan ditampilkan
  /// [label] adalah label informasi
  /// [value] adalah nilai informasi
  Widget _buildWeatherInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accentBlue, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CommonHeader(title: 'Cuaca'),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Search bar dengan autocomplete
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: CompositedTransformTarget(
                        link: _layerLink,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Cari lokasi...',
                            prefixIcon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accentBlue,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.search, color: AppTheme.textSecondary),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchSuggestions = [];
                                      });
                                    },
                                  )
                                : null,
                          ),
                          style: const TextStyle(color: AppTheme.textPrimary),
                          onSubmitted: (_) => _searchLocation(),
                        ),
                      ),
                    ),
                    // Konten cuaca
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.accentBlue,
                              ),
                            )
                          : _errorMessage.isNotEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 64,
                                        color: AppTheme.red,
                                      ),
                                      const SizedBox(height: 16),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 32),
                                        child: Text(
                                          _errorMessage,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => _loadWeather(_currentLocation),
                                        child: const Text('Coba Lagi'),
                                      ),
                                    ],
                                  ),
                                )
                              : _weather == null
                                  ? const Center(
                                      child: Text(
                                        'Pencarian lokasi untuk melihat cuaca',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: Column(
                                        children: [
                                          _buildCurrentWeather(),
                                          _buildForecastSection(),
                                        ],
                                      ),
                                    ),
                    ),
                  ],
                ),
                // Autocomplete suggestions overlay
                if (_searchSuggestions.isNotEmpty && _searchController.text.isNotEmpty)
                  CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: const Offset(0, 56),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.surface,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 32,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchSuggestions.length > 5 ? 5 : _searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _searchSuggestions[index];
                            return InkWell(
                              onTap: () {
                                _searchController.text = suggestion;
                                _loadWeather(suggestion);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: AppTheme.accentBlue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        suggestion,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
