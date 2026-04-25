import 'package:flutter/material.dart';
import 'screens/masjid_list.dart';
import 'services/notification_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize + reschedule notifications in the background — don't block boot
  NotificationService().rescheduleFromSettings();
  runApp(const MasjidApp());
}

class MasjidApp extends StatelessWidget {
  const MasjidApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Masjid Timings',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const MasjidListScreen(),
    );
  }
}
