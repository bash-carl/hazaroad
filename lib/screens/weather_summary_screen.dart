import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/weather_service.dart';

class WeatherSummaryScreen extends StatefulWidget {
  const WeatherSummaryScreen({Key? key}) : super(key: key);

  @override
  _WeatherSummaryScreenState createState() => _WeatherSummaryScreenState();
}

class _WeatherSummaryScreenState extends State<WeatherSummaryScreen> {
  final WeatherService _wx = WeatherService();
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _data = null;
    });
    // Fetch for Lopez, Quezon (13.884° N, 122.260° E)
    final d = await _wx.fetchWeather(lat: 13.884, lon: 122.260);
    if (mounted) {
      setState(() {
        _data = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _data == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final current = _data!['current'];
    final daily = _data!['daily'];
    final hourly = _data!['hourly'];

    final temp = (current['temperature_2m'] as num).round();
    final code = current['weather_code'] as int;
    final isDay = (current['is_day'] ?? 1) == 1;
    final desc = _wx.getWeatherDescription(code);

    final maxT = (daily['temperature_2m_max'][0] as num).round();
    final minT = (daily['temperature_2m_min'][0] as num).round();

    return Scaffold(
      backgroundColor: Colors.transparent, // allow MainNav background or set here
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'Weather Assets/Weather Bg/night.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          
          // Weather Info Text
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Lopez',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$temp°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w200,
                    height: 1.0,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.grey, // or Colors.white70
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'H:$maxT°   L:$minT°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // House Image
          Positioned(
            top: 320,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'Weather Assets/Weather Bg/House.png',
                width: MediaQuery.of(context).size.width * 0.9,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),

          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 350,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Reduced blur for better quality
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B3259).withOpacity(0.6), // deep purple tint
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      // Drag handle
                      Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Hourly Forecast',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 110,
                                  height: 1,
                                  color: Colors.white.withOpacity(0.5),
                                )
                              ],
                            ),
                            const Text(
                              'Weekly Forecast',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Divider(color: Colors.white.withOpacity(0.2), height: 1),
                      const SizedBox(height: 20),
                      // Horizontal List
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 24, // 24 hours
                          itemBuilder: (context, i) {
                            final now = DateTime.now();
                            final targetHour = (now.hour + i).clamp(0, 23);
                            final isHighlight = i == 0;
                            
                            String timeLabel;
                            if (isHighlight) {
                              timeLabel = 'Now';
                            } else {
                              final hour12 = targetHour % 12 == 0 ? 12 : targetHour % 12;
                              final amPm = targetHour < 12 ? 'AM' : 'PM';
                              timeLabel = '$hour12 $amPm';
                            }

                            final hTemp = (hourly['temperature_2m'][targetHour] as num).round();
                            final hProb = hourly['precipitation_probability'][targetHour] as int? ?? 0;
                            final hCode = hourly['weather_code'][targetHour] as int? ?? 0;
                            final hIsDay = targetHour > 6 && targetHour < 18;

                            final iconAsset = _wx.getWeatherIconAsset(hCode, isDay: hIsDay);

                            return _buildForecastPill(
                              time: timeLabel,
                              iconAsset: iconAsset,
                              temp: '$hTemp°',
                              rainChance: hProb > 0 ? '$hProb%' : null,
                              isHighlighted: isHighlight,
                            );
                          },
                        ),
                      ),
                      // Padding for bottom nav bar space
                      const SizedBox(height: 80), 
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastPill({
    required String time,
    required String iconAsset,
    required String temp,
    String? rainChance,
    bool isHighlighted = false,
  }) {
    return Container(
      width: 65,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF48319D) : const Color(0xFF3B3259).withOpacity(0.5),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isHighlighted ? const Color(0xFF6A57B6) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(5, 5),
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Image.asset(iconAsset, width: 35, height: 35, filterQuality: FilterQuality.high),
          if (rainChance != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                rainChance,
                style: const TextStyle(
                  color: Color(0xFF40CBD8), // cyan color for rain chance
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 10), // spacer to align temps
          const SizedBox(height: 10),
          Text(
            temp,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
