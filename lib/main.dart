import 'package:flutter/material.dart';
import 'package:onepetri/Screens/home_screen.dart';
import 'package:onepetri/Screens/setting_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnePetri',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/':(context) => const HomePage(),
        '/settings':(context) => const Settings(),//placeholder
      }
    );
  }
}