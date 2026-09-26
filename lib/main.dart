import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'alarm_service.dart';
import 'models.dart';
import 'photos.dart';
import 'screens/home_screen.dart';
import 'screens/ring_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AlarmService.init(onTap: _openRingScreen);
  await PhotoStore.init();

  // Luôn đồng bộ lại chuông mỗi khi mở app, phòng khi máy đã xoá lịch.
  final medicines = await MedicineStore.load();
  await AlarmService.sync(medicines);

  final launch = await AlarmService.launchResponse();
  runApp(NhacUongThuocApp(launchResponse: launch));
}

/// Mở màn hình chuông khi bấm vào thông báo (hoặc khi chuông hiện toàn màn hình).
void _openRingScreen(NotificationResponse response) {
  if (response.actionId == AlarmService.takenActionId) return;
  final payload = response.payload;
  if (payload == null) return;
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => RingScreen(payload: payload)),
  );
}

class NhacUongThuocApp extends StatelessWidget {
  const NhacUongThuocApp({super.key, this.launchResponse});

  final NotificationResponse? launchResponse;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nhắc uống thuốc',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6FB8)),
        useMaterial3: true,
      ),
      // Chữ to hơn mặc định cho dễ đọc, nhưng vẫn tôn trọng cỡ chữ của máy nếu đã to hơn.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = math.max(1.2, mq.textScaler.scale(1));
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: HomeScreen(launchResponse: launchResponse),
    );
  }
}
