import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/map_provider.dart';
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
      providers: [ChangeNotifierProvider(create: (_) => MapProvider())],
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
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          background: AppColors.bg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: AppColors.muted),
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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    MapScreen(),
    WeatherSummaryScreen(),
    ModelImportScreen(),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 100, // accommodate the curve
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Background TabBar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image.asset(
                'Weather Assets/ui/TabBar.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            // Icons
            Positioned(
              bottom: 25,
              left: 60,
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 0),
                child: Image.asset(
                  'Weather Assets/ui/map.png',
                  width: 24,
                  height: 24,
                  color: _selectedIndex == 0 ? Colors.white : Colors.white70,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              bottom: 30, // center button is raised
              child: GestureDetector(
                onTap: () {
                  // AI action or something
                },
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'Weather Assets/ui/buttonmid.png',
                    width: 60,
                    height: 60,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 25,
              right: 60,
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 1),
                child: Image.asset(
                  'Weather Assets/ui/info.png', // or list icon
                  width: 24,
                  height: 24,
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
