import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:ui';
import 'dart:math';
import 'services/map_provider.dart';
import 'services/weather_provider.dart';
import 'services/weather_service.dart';
import 'services/llm_service.dart';
import 'screens/model_import_screen.dart';
import 'screens/map_screen.dart';
import 'screens/weather_summary_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      child: const HazaroadApp(),
    ),
  );
}

class HazaroadApp extends StatelessWidget {
  const HazaroadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hazaroad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent, // Allow background to show
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          background: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.text, fontSize: 14),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ─── Design Tokens ────────────────────────────────────────────────────────────
class AppColors {
  static const bg       = Color(0xFF0C0C0C);
  static const surface  = Color(0xFF161616);
  static const border   = Color(0xFF242424);
  static const text     = Color(0xFFE8E8E8);
  static const muted    = Color(0xFF737373);
  static const accent   = Color(0xFF4F8EF7);  // single blue accent
  static const success  = Color(0xFF22C55E);
  static const danger   = Color(0xFFEF4444);
}

// ─── Navigation ───────────────────────────────────────────────────────────────
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

enum HazaAIState { idle, listening, processing, answering }

class _MainNavigationScreenState extends State<MainNavigationScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;

  // Haza AI State
  HazaAIState _aiState = HazaAIState.idle;
  String _userSpokenText = "";
  String _aiResponseText = "";
  late stt.SpeechToText _speech;
  bool _isSpeechInitialized = false;
  StreamSubscription? _llmSubscription;

  // TTS & Animation
  late FlutterTts _flutterTts;
  String _sentenceBuffer = "";
  late AnimationController _rainbowController;

  static const List<Widget> _screens = [
    MapScreen(),
    WeatherSummaryScreen(),
    ModelImportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _initSpeech();
    _initTts();

    _rainbowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _llmSubscription = LLMService().onTokenStream.listen((event) {
      final rawText = event['text'] as String?;
      if (rawText != null && _aiState != HazaAIState.idle) {
        // Strip markdown and newlines so the text and TTS remain clean
        final text = rawText.replaceAll('**', '').replaceAll('\n', ' ');
        
        setState(() {
          if (_aiState == HazaAIState.processing) {
            _aiState = HazaAIState.answering;
          }
          _aiResponseText += text;
        });

        _sentenceBuffer += text;
        if (text.contains('.') || text.contains('?') || text.contains('!')) {
          if (_sentenceBuffer.trim().isNotEmpty) {
            _flutterTts.speak(_sentenceBuffer.trim());
          }
          _sentenceBuffer = "";
        }
      }
    });
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(0.95);
    await _flutterTts.setSpeechRate(0.45);
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _isSpeechInitialized = await _speech.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_isSpeechInitialized) {
      // Try initializing again
      _isSpeechInitialized = await _speech.initialize();
      if (!_isSpeechInitialized) return;
    }
    setState(() {
      _aiState = HazaAIState.listening;
      _userSpokenText = "";
      _aiResponseText = "";
    });
    await _speech.listen(onResult: (result) {
      setState(() {
        _userSpokenText = result.recognizedWords;
      });
    });
  }

  void _stopListeningAndProcess() async {
    await _speech.stop();
    if (_userSpokenText.isEmpty) {
      setState(() {
        _aiState = HazaAIState.idle;
      });
      return;
    }
    
    setState(() {
      _aiState = HazaAIState.processing;
    });

    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    String weatherContext = "Unknown weather.";
    if (weatherProvider.data != null) {
      final current = weatherProvider.data!['current'];
      final temp = (current['temperature_2m'] as num).round();
      final code = current['weather_code'] as int;
      final desc = WeatherService().getWeatherDescription(code);
      weatherContext = "Lopez, Quezon: $temp°C, $desc";
    }

    final systemPrompt = "System: Your name is Haza. You are a friendly, conversational AI companion. "
        "Only mention the weather if the user explicitly asks about it. (Hidden Context: Current weather is $weatherContext). "
        "Speak naturally in 1-2 short sentences. Do NOT use markdown formatting like ** or newlines.\n"
        "User: $_userSpokenText\nHaza:";

    final success = await LLMService().generate(systemPrompt);
    if (!success) {
      setState(() {
        _aiState = HazaAIState.answering;
        _aiResponseText = "Sorry, I couldn't process that. Is the model loaded?";
      });
      _flutterTts.speak("Sorry, I couldn't process that.");
    } else {
      // LLM finished generating. Flush any remaining words in the buffer.
      if (_sentenceBuffer.trim().isNotEmpty) {
        _flutterTts.speak(_sentenceBuffer.trim());
        _sentenceBuffer = "";
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _llmSubscription?.cancel();
    _rainbowController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Widget _buildHazaAICapsule() {
    double width;
    double height;
    BorderRadius borderRadius;

    switch (_aiState) {
      case HazaAIState.idle:
        width = 0;
        height = 0;
        borderRadius = BorderRadius.circular(60);
        break;
      case HazaAIState.listening:
      case HazaAIState.processing:
        width = MediaQuery.of(context).size.width * 0.85;
        height = 70;
        borderRadius = BorderRadius.circular(35);
        break;
      case HazaAIState.answering:
        width = MediaQuery.of(context).size.width * 0.9;
        height = 300;
        borderRadius = BorderRadius.circular(24);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutExpo,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _aiState == HazaAIState.processing ? Colors.transparent : const Color(0xFF3B3259).withOpacity(0.85),
        borderRadius: borderRadius,
        border: _aiState == HazaAIState.processing ? null : Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        boxShadow: _aiState == HazaAIState.processing ? [] : [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_aiState == HazaAIState.processing)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _rainbowController,
                builder: (context, child) {
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: SweepGradient(
                          transform: GradientRotation(_rainbowController.value * 2 * pi),
                          colors: const [
                            Color(0xFF4285F4),
                            Color(0xFF9B72CB),
                            Color(0xFFD96570),
                            Color(0xFFF4B400),
                            Color(0xFF4285F4),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: const Color(0xFF3B3259).withOpacity(0.85),
                  child: _buildAIContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIContent() {
    if (_aiState == HazaAIState.idle) return const SizedBox.shrink();

    if (_aiState == HazaAIState.listening) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 70, // Fixed height to match container target
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(Icons.mic, color: Colors.white, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  _userSpokenText.isEmpty ? "Listening... (Speak now)" : _userSpokenText,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_aiState == HazaAIState.processing) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Container(
          height: 70,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.auto_awesome, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text("Thinking...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (_aiState == HazaAIState.answering) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
                const SizedBox(width: 8),
                const Text("Haza Intelligence", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _aiState = HazaAIState.idle;
                      _aiResponseText = "";
                      _userSpokenText = "";
                      _sentenceBuffer = "";
                    });
                    _flutterTts.stop();
                  },
                  child: const Icon(Icons.close, color: Colors.white70, size: 22),
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _aiResponseText,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final weatherProvider = Provider.of<WeatherProvider>(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black, // fallback
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              child: Image.asset(
                weatherProvider.backgroundAsset,
                key: ValueKey<String>(weatherProvider.backgroundAsset),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          // Screens
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            physics: const BouncingScrollPhysics(),
            children: _screens,
          ),
          
          // Haza AI Overlay
          Positioned(
            bottom: 120, // Sit right above the curve
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildHazaAICapsule(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 100, // accommodate the curve
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Background TabBar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'Weather Assets/ui/TabBar.png',
                fit: BoxFit.cover,
                width: double.infinity,
                filterQuality: FilterQuality.high,
              ),
            ),
            // Icons
            Positioned(
              bottom: 21,
              left: 60,
              child: GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Image.asset(
                  'Weather Assets/ui/map.png',
                  width: 40,
                  height: 40,
                  color: _selectedIndex == 0 ? Colors.white : Colors.white70,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              bottom: -10, // Adjusted to bring the large icon down into the curve
              child: GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListeningAndProcess(),
                onTap: () {
                  // Standard tap could trigger a tip or toggle AI idle state
                },
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'Weather Assets/ui/buttonmid.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 21,
              right: 60,
              child: GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    1, // Note: Swiping right brings up screen 2 (ModelImport), swiping left from screen 0 brings up screen 1.
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Image.asset(
                  'Weather Assets/ui/info.png',
                  width: 40,
                  height: 40,
                  color: _selectedIndex == 1 ? Colors.white : Colors.white70,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
