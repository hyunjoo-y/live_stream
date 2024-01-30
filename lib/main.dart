import 'package:flutter/material.dart';
import 'package:live_streaming/screens/home_page.dart';

void main() {
  runApp(const MainApp(homePage: HomePage(),));
}

class MainApp extends StatelessWidget {
  const MainApp({Key? key, required this.homePage}) : super(key: key);
  final Widget homePage;

 @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlockLiveS',
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: homePage,
      ),
    );
  }
}
