import 'package:flutter/material.dart';
import 'screens/masjid_list.dart';
import 'theme.dart';

void main() => runApp(const MasjidApp());

class MasjidApp extends StatelessWidget {
  const MasjidApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Masjids of Nellore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const MasjidListScreen(),
    );
  }
}
