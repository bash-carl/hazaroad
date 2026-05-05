import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hazard_model.dart';
import '../models/flood_model.dart';
import 'llm_service.dart';

enum MapInteractionMode { none, pinning, drawing }

class MapProvider with ChangeNotifier {
  // --- Map State ---
  List<Hazard> _hazards = [];
  List<FloodLine> _floodLines = [];
  MapInteractionMode _mode = MapInteractionMode.none;
  bool _isOfficial = false;
  List<LatLng> _currentDrawingPoints = [];

  // --- Weather ---
  bool _showWeather = false;
  bool _useSatellite = false;
  String? _weatherTileUrl;

  // --- AI ---
  String _aiSummary = '';
  bool _isAILoading = false;

  // --- Model ---
  bool _isModelLoaded = false;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  // --- LLM ---
  final LLMService _llmService = LLMService();
  StreamSubscription? _tokenSubscription;
  bool _isFirstToken = true;

  // --- Getters ---
  List<Hazard> get hazards => _hazards;
  List<FloodLine> get floodLines => _floodLines;
  MapInteractionMode get mode => _mode;
  bool get isOfficial => _isOfficial;
  List<LatLng> get currentDrawingPoints => _currentDrawingPoints;
  bool get showWeather => _showWeather;
  bool get useSatellite => _useSatellite;
  String? get weatherTileUrl => _weatherTileUrl;
  String get aiSummary => _aiSummary;
  bool get isAILoading => _isAILoading;
  bool get isModelLoaded => _isModelLoaded;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  MapProvider() {
    _subscribeToTokens();
    _initPersistence();
  }

  // ─────────────── AI Token Stream ───────────────

  void _subscribeToTokens() {
    _tokenSubscription = _llmService.onTokenStream.listen((event) {
      final text = event['text'] as String? ?? '';
      final done = event['done'] as bool? ?? false;

      if (text.isNotEmpty) {
        if (_isFirstToken) {
          _aiSummary = text;
          _isFirstToken = false;
        } else {
          _aiSummary += text;
        }
        notifyListeners();
      }

      if (done) {
        _isAILoading = false;
        _isFirstToken = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    super.dispose();
  }

  // ─────────────── Persistence ───────────────

  Future<void> _initPersistence() async {
    await loadSavedData();
    await _autoLoadModel();
  }

  Future<void> _autoLoadModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelPath = '${dir.path}/hazaai_1b.task';
    if (await File(modelPath).exists()) {
      debugPrint('Hazaroad: AI Model file found at $modelPath. Loading...');
      _isModelLoaded = await _llmService.loadModel(modelPath);
      debugPrint('Hazaroad: AI Model loaded = $_isModelLoaded');
    } else {
      debugPrint('Hazaroad: AI Model NOT found at $modelPath');
    }
    notifyListeners();
  }

  Future<void> loadSavedData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      final hazardFile = File('${dir.path}/hazards.json');
      if (await hazardFile.exists()) {
        final List<dynamic> list = json.decode(await hazardFile.readAsString());
        _hazards = list.map((j) => Hazard.fromJson(j)).toList();
      }

      final floodFile = File('${dir.path}/floods.json');
      if (await floodFile.exists()) {
        final List<dynamic> list = json.decode(await floodFile.readAsString());
        _floodLines = list.map((j) => FloodLine.fromJson(j)).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/hazards.json')
          .writeAsString(json.encode(_hazards.map((h) => h.toJson()).toList()));
      await File('${dir.path}/floods.json')
          .writeAsString(json.encode(_floodLines.map((f) => f.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  // ─────────────── Map Interactions ───────────────

  void toggleOfficial() {
    _isOfficial = !_isOfficial;
    if (!_isOfficial) {
      _mode = MapInteractionMode.none;
      _currentDrawingPoints = [];
    }
    notifyListeners();
  }

  void setMode(MapInteractionMode mode) {
    if (!_isOfficial) return;
    _mode = mode;
    _currentDrawingPoints = [];
    notifyListeners();
  }

  void addHazard(LatLng location, HazardType type, {String description = ''}) {
    _hazards.add(Hazard(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      location: location,
      type: type,
      timestamp: DateTime.now(),
      reporterName: 'Official User',
      description: description,
    ));
    _mode = MapInteractionMode.none;
    _saveData();
    notifyListeners();
  }

  void startDrawing() {
    _currentDrawingPoints = [];
    notifyListeners();
  }

  void addPointToDrawing(LatLng point) {
    _currentDrawingPoints.add(point);
    notifyListeners();
  }

  void finishDrawing({String description = '', String depth = ''}) {
    if (_currentDrawingPoints.length > 1) {
      _floodLines.add(FloodLine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        points: List.from(_currentDrawingPoints),
        timestamp: DateTime.now(),
        reporterName: 'Official User',
        description: description,
        depth: depth,
      ));
    }
    _currentDrawingPoints = [];
    _mode = MapInteractionMode.none;
    _saveData();
    notifyListeners();
  }

  void clearDrawing() {
    _currentDrawingPoints = [];
    notifyListeners();
  }

  // ─────────────── Weather ───────────────

  Future<void> toggleWeather() async {
    _showWeather = !_showWeather;
    if (_showWeather) await fetchWeatherRadar();
    notifyListeners();
  }

  void toggleSatellite() {
    _useSatellite = !_useSatellite;
    if (_showWeather) fetchWeatherRadar();
    notifyListeners();
  }

  Future<void> fetchWeatherRadar() async {
    try {
      final response = await http.get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String host = data['host'] ?? 'https://tilecache.rainviewer.com';
        if (!host.startsWith('http')) host = 'https://$host';

        String? path;
        int scheme = 1;

        if (_useSatellite &&
            data['satellite']?['infrared'] != null &&
            (data['satellite']['infrared'] as List).isNotEmpty) {
          path = data['satellite']['infrared'].last['path'];
          scheme = 0;
        }

        if (path == null &&
            data['radar']?['past'] != null &&
            (data['radar']['past'] as List).isNotEmpty) {
          path = data['radar']['past'].last['path'];
          scheme = 1;
        }

        if (path != null) {
          _weatherTileUrl = '$host$path/256/{z}/{x}/{y}/$scheme/1_1.png';
        } else {
          _showWeather = false;
        }
      }
    } catch (e) {
      debugPrint('Hazaroad: Error fetching weather: $e');
      _showWeather = false;
    }
    notifyListeners();
  }

  // ─────────────── HazaAI ───────────────

  void setAISummary(String summary) {
    _aiSummary = summary;
    notifyListeners();
  }

  void setModelLoaded(bool loaded) {
    _isModelLoaded = loaded;
    notifyListeners();
  }

  Future<void> generateHazaAISummary() async {
    if (_hazards.isEmpty && _floodLines.isEmpty) {
      _aiSummary = 'No active hazards or flood areas reported in Brgy Magsaysay yet.';
      notifyListeners();
      return;
    }

    if (!_isModelLoaded) {
      _aiSummary = 'HazaAI model is not loaded. Please download it from the Model Management screen.';
      notifyListeners();
      return;
    }

    _isAILoading = true;
    _isFirstToken = true;
    _aiSummary = 'HazaAI is analyzing...';
    notifyListeners();

    final buf = StringBuffer();
    buf.write('<start_of_turn>user\n');
    buf.write('You are HazaAI, a disaster response assistant for Brgy Magsaysay, Lopez, Quezon. ');
    buf.write('Summarize the following reports in 2-3 concise sentences. Focus on safety advice.\n\nREPORTS:\n');

    for (var h in _hazards) {
      buf.write('- ${h.typeString.toUpperCase()}: ');
      buf.write(h.description.isNotEmpty
          ? h.description
          : 'Reported at ${h.location.latitude.toStringAsFixed(3)}, ${h.location.longitude.toStringAsFixed(3)}');
      buf.write('\n');
    }
    for (var f in _floodLines) {
      buf.write('- FLOODING');
      if (f.depth.isNotEmpty) buf.write(' (Depth: ${f.depth})');
      if (f.description.isNotEmpty) buf.write(': ${f.description}');
      buf.write('\n');
    }
    buf.write('\nSUMMARY:<end_of_turn>\n<start_of_turn>model\n');

    try {
      final success = await _llmService.generate(buf.toString());
      if (!success) {
        _aiSummary = 'HazaAI: Failed to generate. Make sure the model is loaded.';
        _isAILoading = false;
        _isFirstToken = true;
        notifyListeners();
      }
      // On success: tokens arrive via _subscribeToTokens()
    } catch (e) {
      _aiSummary = 'HazaAI Error: $e';
      _isAILoading = false;
      _isFirstToken = true;
      notifyListeners();
    }
  }

  // ─────────────── Model Download ───────────────

  Future<void> startModelDownload() async {
    _isDownloading = true;
    notifyListeners();

    final success = await _llmService.downloadAndLoadModel(
      '1bbc7_AWbvvBdSJptToIbP4gFTxE4r2H_',
      (progress) {
        _downloadProgress = progress;
        notifyListeners();
      },
    );

    _isModelLoaded = success;
    _isDownloading = false;
    notifyListeners();
  }
}
