import 'package:flutter/material.dart';
import 'weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _wx = WeatherService();
  bool isLoading = true;
  Map<String, dynamic>? data;
  String backgroundAsset = 'Weather Assets/assets/night.png';

  WeatherProvider() {
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    isLoading = true;
    notifyListeners();

    // Fetch for Lopez, Quezon (13.884° N, 122.260° E)
    final d = await _wx.fetchWeather(lat: 13.884, lon: 122.260);
    
    if (d != null) {
      data = d;
      final current = d['current'];
      final code = current['weather_code'] as int;
      final isDay = (current['is_day'] ?? 1) == 1;
      backgroundAsset = _wx.getWeatherBackgroundAsset(code, isDay: isDay);
    }
    
    isLoading = false;
    notifyListeners();
  }
}
