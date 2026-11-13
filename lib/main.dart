import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'screens/today_screen.dart';
import 'screens/program_screen.dart';
import 'screens/stats_screen.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarBrightness: Brightness.dark),
  );

  // Restaure depuis le backup JSON si les données locales sont absentes
  await StorageService.restoreFromBackup();
  await NotificationService.refresh();

  runApp(const RunSemiApp());
}

class RunSemiApp extends StatelessWidget {
  const RunSemiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunSemi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.accentPrimary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: AppTheme.textTheme,
      ),
      // Fond d'écran global (halo + pailletis façon Gemini), derrière tous les écrans.
      builder: (context, child) => Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          if (child != null) child,
        ],
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _items = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: "Aujourd'hui"),
    (icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Programme'),
    (icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart, label: 'Stats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: switch (_index) {
              0 => const TodayScreen(),
              1 => const ProgramScreen(),
              2 => const StatsScreen(),
              _ => const TodayScreen(),
            },
          ),
          // Figma "accueil (base)" : navbar à 44 px du bas, 20 px des bords.
          Positioned(
            left: 20,
            right: 20,
            bottom: 44,
            child: _buildGlassNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassNavBar() {
    const radius = AppTheme.radiusFull;
    return Container(
      // Liseré Figma nav/glass-border (blanc 25 %)
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.navGlassBorder),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.bgApp.withValues(alpha: 0.2), // ombre de la navbar
            offset: const Offset(0, 0),
            blurRadius: 6,
          ),
        ],
      ),
      // Vrai effet "Liquid Glass" (réfraction + aberration chromatique) via liquid_glass_renderer,
      // remplace l'ancien BackdropFilter+ColorFilter.matrix (test).
      child: LiquidGlass.withOwnLayer(
        shape: const LiquidRoundedSuperellipse(borderRadius: radius),
        settings: const LiquidGlassSettings(
          thickness: 18,
          blur: 6,
          chromaticAberration: 0.02,
          glassColor: AppTheme.navGlassBg,
          saturation: 1.4,
          lightIntensity: 0.8,
          ambientStrength: 0.15,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = _index == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _index = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16, vertical: AppTheme.space6),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accentPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.selectedIcon : item.icon,
                          color: AppTheme.textPrimary,
                          size: 22,
                        ),
                        const SizedBox(height: AppTheme.space2),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
