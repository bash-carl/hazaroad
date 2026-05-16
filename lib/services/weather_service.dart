import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<Map<String, dynamic>?> fetchWeather({
    double lat = 14.5995,
    double lon = 120.9842,
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,'
      'precipitation,weather_code,wind_speed_10m,wind_direction_10m,'
      'uv_index,is_day'
      '&hourly=temperature_2m,precipitation_probability,weather_code'
      '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum'
      '&timezone=Asia%2FManila'
      '&forecast_days=1',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  String getWeatherDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 55) return 'Drizzle';
    if (code <= 65) return 'Rain';
    if (code <= 75) return 'Snow';
    if (code <= 82) return 'Rain Showers';
    if (code <= 86) return 'Snow Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  String getWeatherEmoji(int code, {bool isDay = true}) {
    if (code == 0) return isDay ? '☀️' : '🌙';
    if (code <= 3) return isDay ? '⛅' : '🌤️';
    if (code <= 48) return '🌫️';
    if (code <= 55) return '🌦️';
    if (code <= 65) return '🌧️';
    if (code <= 75) return '🌨️';
    if (code <= 82) return '🌦️';
    if (code <= 86) return '🌨️';
    if (code <= 99) return '⛈️';
    return '🌡️';
  }

  String getWeatherIconAsset(int code, {bool isDay = true}) {
    final basePath = 'Weather Assets/cloud icons/';
    if (code == 0 || code <= 3) return isDay ? basePath + 'Sun cloud mid rain.png' : basePath + 'Moon cloud fast wind.png';
    if (code <= 48) return basePath + 'Moon cloud fast wind.png'; // Fog/cloudy
    if (code <= 65 || code <= 82) return isDay ? basePath + 'Sun cloud angled rain.png' : basePath + 'Moon cloud mid rain.png'; // Rain
    if (code <= 99) return basePath + 'Tornado.png'; // Storm/severe
    return basePath + 'Sun cloud mid rain.png'; // Default
  }

  String getWeatherBackgroundAsset(int code, {bool isDay = true}) {
    final basePath = 'Weather Assets/assets/';
    bool isRainy = (code >= 50 && code <= 99);
    
    if (isRainy) {
      return isDay ? basePath + 'rainmorning.png' : basePath + 'rainnight.png';
    } else {
      return isDay ? basePath + 'morning.png' : basePath + 'night.png';
    }
  }

  String getWindDirection(double degrees) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[((degrees + 22.5) / 45).floor() % 8];
  }

  int getUVRisk(double uv) {
    if (uv < 3) return 0;
    if (uv < 6) return 1;
    if (uv < 8) return 2;
    if (uv < 11) return 3;
    return 4;
  }

  String getUVLabel(double uv) {
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'Very High';
    return 'Extreme';
  }
}
