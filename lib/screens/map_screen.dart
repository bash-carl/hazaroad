import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/map_provider.dart';
import '../models/hazard_model.dart';
import '../services/weather_service.dart';
import '../main.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = Provider.of<MapProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Hazaroad'),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white70),
            onPressed: () => _mapController.move(LatLng(13.8859, 122.2630), 15.0),
            tooltip: 'Center on Magsaysay',
          ),
          // AI status dot
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: mapProvider.isModelLoaded ? AppColors.success : AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text('AI', style: TextStyle(
                color: mapProvider.isModelLoaded ? AppColors.success : AppColors.muted,
                fontSize: 11, fontWeight: FontWeight.w600,
              )),
            ]),
          ),
          IconButton(
            icon: Icon(
              mapProvider.showWeather
                  ? (mapProvider.useSatellite ? Icons.satellite_alt : Icons.cloud)
                  : Icons.cloud_outlined,
              size: 20,
            ),
            color: mapProvider.showWeather ? Colors.white : AppColors.muted,
            onPressed: () => mapProvider.toggleWeather(),
            onLongPress: () => mapProvider.toggleSatellite(),
            tooltip: 'Weather (long press: satellite)',
          ),
          IconButton(
            icon: Icon(
              mapProvider.isOfficial ? Icons.verified_user : Icons.person_outline,
              size: 20,
            ),
            color: mapProvider.isOfficial ? AppColors.accent : AppColors.muted,
            onPressed: () => mapProvider.toggleOfficial(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(13.8859, 122.2630),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                if (mapProvider.mode == MapInteractionMode.pinning) {
                  _showHazardDialog(context, mapProvider, point);
                } else if (mapProvider.mode == MapInteractionMode.drawing) {
                  mapProvider.addPointToDrawing(point);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.hazaroad.im',
              ),
              if (mapProvider.showWeather && mapProvider.weatherTileUrl != null)
                Opacity(
                  opacity: 0.6,
                  child: TileLayer(
                    urlTemplate: mapProvider.weatherTileUrl!,
                    userAgentPackageName: 'com.hazaroad.im',
                    tileProvider: NetworkTileProvider(),
                    maxNativeZoom: 8,
                  ),
                ),
              PolylineLayer(
                polylines: [
                  ...mapProvider.floodLines.map((line) => Polyline(
                        points: line.points,
                        color: Colors.blue.withOpacity(0.6),
                        strokeWidth: 8,
                      )),
                  if (mapProvider.currentDrawingPoints.isNotEmpty)
                    Polyline(
                      points: mapProvider.currentDrawingPoints,
                      color: Colors.orange.withOpacity(0.5),
                      strokeWidth: 4,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  const Marker(
                    point: LatLng(13.8859, 122.2630),
                    width: 60,
                    height: 60,
                    child: Icon(Icons.stars, color: Colors.blueAccent, size: 30),
                  ),
                  ...mapProvider.hazards.map((hazard) => Marker(
                        point: hazard.location,
                        width: 40,
                        height: 40,
                        child: Icon(
                          _getHazardIcon(hazard.type),
                          color: _getHazardColor(hazard.type),
                          size: 30,
                        ),
                      )).toList(),
                ],
              ),
            ],
          ),
          if (mapProvider.mode != MapInteractionMode.none)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mapProvider.mode == MapInteractionMode.pinning 
                      ? 'TAP ON MAP TO PIN HAZARD' 
                      : 'TAP POINTS TO DRAW FLOOD AREA',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          if (mapProvider.isOfficial)
            Positioned(
              right: 16,
              top: 100,
              child: Column(
                children: [
                  _ActionButton(
                    icon: Icons.add_location,
                    label: 'Pin',
                    isActive: mapProvider.mode == MapInteractionMode.pinning,
                    onPressed: () => mapProvider.setMode(MapInteractionMode.pinning),
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.gesture,
                    label: 'Draw',
                    isActive: mapProvider.mode == MapInteractionMode.drawing,
                    onPressed: () => mapProvider.setMode(MapInteractionMode.drawing),
                    color: Colors.blueAccent,
                  ),
                  if (mapProvider.mode == MapInteractionMode.drawing && mapProvider.currentDrawingPoints.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'done',
                      mini: true,
                      backgroundColor: Colors.green,
                      child: const Icon(Icons.check),
                      onPressed: () => _showFloodDialog(context, mapProvider),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'clear',
                      mini: true,
                      backgroundColor: Colors.grey,
                      child: const Icon(Icons.close),
                      onPressed: () => mapProvider.clearDrawing(),
                    ),
                  ],
                ],
              ),
            ),
          if (mapProvider.showWeather)
            Positioned(
              top: 80,
              left: 16,
              child: _WeatherStatusCard(),
            ),
          Consumer<MapProvider>(
            builder: (context, provider, _) {
              if (provider.aiSummary.isEmpty) return const SizedBox.shrink();
              return Positioned(
                top: 150,
                left: 16,
                right: 16,
                child: _HazaAISummaryCard(summary: provider.aiSummary),
              );
            },
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mapProvider.hazards.isNotEmpty || mapProvider.floodLines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () => mapProvider.generateHazaAISummary(),
                      icon: const Icon(Icons.psychology, size: 16),
                      label: const Text('Summarize with HazaAI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                _buildWarningCapsules(context, mapProvider),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: mapProvider.showWeather 
        ? FloatingActionButton.extended(
            onPressed: () => _mapController.move(_mapController.camera.center, 8.0),
            label: const Text('Wide View'),
            icon: const Icon(Icons.zoom_out_map),
            backgroundColor: Colors.orangeAccent,
          )
        : null,
    );
  }

  IconData _getHazardIcon(HazardType type) {
    switch (type) {
      case HazardType.pothole: return Icons.warning_amber;
      case HazardType.accident: return Icons.car_crash;
      case HazardType.construction: return Icons.engineering;
      default: return Icons.location_on;
    }
  }

  Color _getHazardColor(HazardType type) {
    switch (type) {
      case HazardType.pothole: return Colors.orange;
      case HazardType.accident: return Colors.red;
      case HazardType.construction: return Colors.yellow[900]!;
      default: return Colors.red;
    }
  }

  void _showHazardDialog(BuildContext context, MapProvider provider, LatLng point) {
    final TextEditingController descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Hazard Detail'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select Hazard Type:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...HazardType.values.map((type) => ListTile(
                leading: Icon(_getHazardIcon(type), color: _getHazardColor(type)),
                title: Text(type.toString().split('.').last.toUpperCase()),
                onTap: () {
                  provider.addHazard(point, type, description: descController.text);
                  Navigator.pop(ctx);
                },
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showFloodDialog(BuildContext context, MapProvider provider) {
    final TextEditingController descController = TextEditingController();
    final TextEditingController depthController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flood Area Details'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: depthController,
              decoration: const InputDecoration(
                labelText: 'Flood Depth',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              provider.finishDrawing(description: descController.text, depth: depthController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Report Flood'),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCapsules(BuildContext context, MapProvider provider) {
    final List<Map<String, dynamic>> items = [
      ...provider.hazards.map((h) => {
        'title': 'POTENTIAL HAZARD',
        'desc': h.description.isNotEmpty ? h.description : '${h.typeString.toUpperCase()} reported',
        'color': _getHazardColor(h.type),
        'icon': _getHazardIcon(h.type),
      }),
      ...provider.floodLines.map((f) => {
        'title': 'FLOOD ALERT ${f.depth.isNotEmpty ? "("+f.depth+")" : ""}',
        'desc': f.description.isNotEmpty ? f.description : 'Flooding reported in this area',
        'color': Colors.blue,
        'icon': Icons.water_drop,
      }),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[items.length - 1 - i];
          return Container(
            width: 240,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
              border: Border.all(color: item['color'], width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: item['color'].withOpacity(0.1),
                  child: Icon(item['icon'], color: item['color'], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: item['color'])),
                      Text(item['desc'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HazaAISummaryCard extends StatelessWidget {
  final String summary;
  const _HazaAISummaryCard({required this.summary});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.deepPurple.shade900, Colors.deepPurple.shade600]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              const Text('HazaAI powered by Gemma', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18), onPressed: () => Provider.of<MapProvider>(context, listen: false).setAISummary('')),
            ],
          ),
          const Divider(color: Colors.white30),
          Text(summary, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}


class _WeatherStatusCard extends StatefulWidget {
  @override
  State<_WeatherStatusCard> createState() => _WeatherStatusCardState();
}

class _WeatherStatusCardState extends State<_WeatherStatusCard> {
  Map<String, dynamic>? _weather;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _loadWeather();
  }
  Future<void> _loadWeather() async {
    final data = await WeatherService().fetchWeather(lat: 13.8859, lon: 122.2630);
    if (mounted) setState(() { _weather = data; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const CircularProgressIndicator();
    if (_weather == null) return const SizedBox.shrink();
    final current = _weather!['current'];
    final temp = current['temperature_2m'];
    final condition = WeatherService().getWeatherDescription(current['weather_code']);
    final isRaining = current['precipitation'] > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [Icon(isRaining ? Icons.umbrella : Icons.wb_sunny, color: Colors.orangeAccent, size: 16), const SizedBox(width: 8), Text('$temp°C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
          Text(condition, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          if (isRaining) const Text('RAIN DETECTED', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 9)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final Color color;
  const _ActionButton({required this.icon, required this.label, required this.isActive, required this.onPressed, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(heroTag: label, onPressed: onPressed, backgroundColor: isActive ? color : Colors.white, child: Icon(icon, color: isActive ? Colors.white : Colors.black87)),
        const SizedBox(height: 4),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10))),
      ],
    );
  }
}
