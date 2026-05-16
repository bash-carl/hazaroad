import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../services/weather_provider.dart';
import '../services/weather_service.dart';

class WeatherSummaryScreen extends StatefulWidget {
  const WeatherSummaryScreen({Key? key}) : super(key: key);

  @override
  State<WeatherSummaryScreen> createState() => _WeatherSummaryScreenState();
}

class _WeatherSummaryScreenState extends State<WeatherSummaryScreen> {
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0.41);

  @override
  void dispose() {
    _sheetExtent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WeatherProvider>(context);

    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (provider.data == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              const Text('Weather data unavailable', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => provider.fetchWeather(),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final data = provider.data!;
    final current = data['current'];
    final daily = data['daily'];
    final hourly = data['hourly'];

    final temp = (current['temperature_2m'] as num).round();
    final code = current['weather_code'] as int;
    final isDay = (current['is_day'] ?? 1) == 1;
    final wx = WeatherService();
    final desc = wx.getWeatherDescription(code);

    final maxT = (daily['temperature_2m_max'][0] as num).round();
    final minT = (daily['temperature_2m_min'][0] as num).round();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The House Illustration
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'Weather Assets/assets/House.png',
                width: MediaQuery.of(context).size.width * 0.95,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          
          // Deep blur background overlay that transitions as the sheet is pulled up
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, child) {
                final ratio = ((extent - 0.41) / (0.85 - 0.41)).clamp(0.0, 1.0);
                if (ratio == 0.0) return const SizedBox.shrink();
                
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: ratio * 30, sigmaY: ratio * 30),
                  child: Container(
                    color: const Color(0xFF3B3259).withOpacity(ratio * 0.6),
                  ),
                );
              },
            ),
          ),
          
          // Weather Header Text
          Positioned(
            top: MediaQuery.of(context).padding.top + 40,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, child) {
                final expandRatio = ((extent - 0.41) / (0.85 - 0.41)).clamp(0.0, 1.0);
                final largeOpacity = 1.0 - (expandRatio * 2).clamp(0.0, 1.0);
                final smallOpacity = ((expandRatio - 0.5) * 2).clamp(0.0, 1.0);
                
                return Column(
                  children: [
                    const Text(
                      'Lopez, Quezon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Opacity(
                          opacity: largeOpacity,
                          child: Column(
                            children: [
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
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
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
                        Opacity(
                          opacity: smallOpacity,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$temp° | $desc',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Draggable Bottom Sheet
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              _sheetExtent.value = notification.extent;
              return false;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.41,
              minChildSize: 0.41,
              maxChildSize: 0.85,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B3259).withOpacity(0.6),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _StickyHeaderDelegate(
                            height: 75,
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  color: const Color(0xFF3B3259).withOpacity(0.7),
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
                                      const Spacer(),
                                      Divider(color: Colors.white.withOpacity(0.2), height: 1),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              // Hourly Forecast List
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

                                final iconAsset = wx.getWeatherIconAsset(hCode, isDay: hIsDay);

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
                          const SizedBox(height: 20),
                          // Grid of detail cards
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ValueListenableBuilder<double>(
                              valueListenable: _sheetExtent,
                              builder: (context, extent, child) {
                                // Fade in between 0.41 and 0.65 extent
                                final opacity = ((extent - 0.41) / (0.65 - 0.41)).clamp(0.0, 1.0);
                                return Opacity(
                                  opacity: opacity,
                                  child: child,
                                );
                              },
                              child: _buildDetailsGrid(current, wx),
                            ),
                          ),
                              const SizedBox(height: 120), // Spacer for bottom nav
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ), // Close NotificationListener
        ],
      ),
    );
  }

  Widget _buildDetailsGrid(Map<String, dynamic> current, WeatherService wx) {
    final uv = (current['uv_index'] as num?)?.toDouble() ?? 0.0;
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
    final rain = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
    
    return Column(
      children: [
        // Air Quality Card (Full width)
        _buildDetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.air, color: Colors.white.withOpacity(0.5), size: 16),
                  const SizedBox(width: 8),
                  Text('AIR QUALITY', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('3-Low Health Risk', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(colors: [Colors.blue, Colors.pinkAccent]),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('See more', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 20),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Text('UV INDEX', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${uv.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w400)),
                    Text(wx.getUVLabel(uv), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(colors: [Colors.blue, Colors.pinkAccent]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.wb_twilight, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Text('SUNRISE', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('5:28 AM', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 8),
                    // Dummy sine wave graph
                    SizedBox(
                      height: 30,
                      child: CustomPaint(
                        painter: SineWavePainter(),
                        size: const Size(double.infinity, 30),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Sunset: 7:25PM', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.air, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Text('WIND', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.explore_outlined, color: Colors.white.withOpacity(0.2), size: 80),
                          Column(
                            children: [
                              Text('${wind.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                              const Text('km/h', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.water_drop_outlined, color: Colors.white.withOpacity(0.5), size: 16),
                        const SizedBox(width: 8),
                        Text('RAINFALL', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${rain.toStringAsFixed(1)} mm', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 4),
                    const Text('in last hour', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2244).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: child,
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
        color: isHighlighted ? const Color(0xFF48319D) : const Color(0xFF2C2244).withOpacity(0.4),
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

class SineWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height);
    path.quadraticBezierTo(size.width / 2, -size.height * 0.5, size.width, size.height);

    canvas.drawPath(path, paint);

    // Draw the dot on the path
    final dotPaint = Paint()..color = Colors.white;
    final dotPaintGlow = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final dotX = size.width * 0.25;
    final dotY = size.height * 0.45;

    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaintGlow);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}
