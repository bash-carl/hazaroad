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

  static const _navItems = [
    _NavItemData(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map'),
    _NavItemData(icon: Icons.cloud_outlined, activeIcon: Icons.cloud, label: 'Weather'),
    _NavItemData(icon: Icons.memory_outlined, activeIcon: Icons.memory, label: 'AI Model'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        color: AppColors.bg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top divider
            const Divider(height: 1, thickness: 1, color: AppColors.border),
            SafeArea(
              child: SizedBox(
                height: 56,
                child: Row(
                  children: List.generate(_navItems.length, (i) {
                    final item = _navItems[i];
                    final selected = _selectedIndex == i;
                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedIndex = i),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected ? item.activeIcon : item.icon,
                              size: 22,
                              color: selected ? Colors.white : AppColors.muted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: selected ? Colors.white : AppColors.muted,
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({required this.icon, required this.activeIcon, required this.label});
}
