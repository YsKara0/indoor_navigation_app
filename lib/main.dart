import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/config/env_config.dart';
import 'core/theme/app_theme.dart';
import 'services/services.dart';
import 'screens/screens.dart';

/// Ana uygulama giriş noktası
void main() async {
  // Flutter binding'lerini başlat
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yükle
  await dotenv.load(fileName: '.env');

  // Sistem UI ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Sistem navigation bar'ı edge-to-edge yap
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Yalnızca dikey mod
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const IndoorNavigationApp());
}

/// Ana uygulama widget'ı
class IndoorNavigationApp extends StatelessWidget {
  const IndoorNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Demo Servisi (her zaman eklenir, ama sadece demo modunda kullanılır)
        ChangeNotifierProvider<DemoService>(
          create: (_) => DemoService(),
        ),
        // BLE Servisi
        ChangeNotifierProvider<BleService>(
          create: (_) => BleService(),
        ),
        // WebSocket Servisi
        ChangeNotifierProvider<WebSocketService>(
          create: (_) => WebSocketService(),
        ),
      ],
      child: MaterialApp(
        title: 'Indoor Navigation',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const NavigationScreen(),
      ),
    );
  }
}
