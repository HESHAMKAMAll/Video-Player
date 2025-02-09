import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/video_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // تعيين اتجاه الشاشة الافتراضي للوضع العمودي
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoProvider(),
      child: MaterialApp(
        title: 'Video Player',
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark().copyWith(
          primaryColor: Colors.red,
          // scaffoldBackgroundColor: Colors.grey[900],
          appBarTheme:  AppBarTheme(
            backgroundColor: Color(0xFF1C1C20),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // استخدام الوضع المظلم تلقائياً حسب إعدادات النظام
        themeMode: ThemeMode.dark,
        // دعم اللغة العربية
        locale: const Locale('ar', 'SA'),
        home: const FolderListScreen(),
      ),
    );
  }
}

// إضافة امتداد للألوان
extension ColorExtension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighten([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}