import 'package:flutter/material.dart';

import 'home_page.dart';

void main() => runApp(const TvHomeApp());

class TvHomeApp extends StatelessWidget {
  const TvHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Manrope'),
      home: const Scaffold(
        backgroundColor: Color(0xFF0B0F12),
        // Lay out on a fixed 1920×1080 canvas and scale it to whatever the TV reports.
        body: FittedBox(
          child: SizedBox(width: 1920, height: 1080, child: HomePage()),
        ),
      ),
    );
  }
}
