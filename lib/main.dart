// ignore_for_file: avoid_web_libraries_in_flutter, avoid_print, depend_on_referenced_packages

import 'package:scaled_app/scaled_app.dart';
import 'dialer.dart';
import 'package:flutter/material.dart';

void main() {
  runAppScaled(const MyApp(), scaleFactor: (deviceSize) {
    const double widthOfDesign = 350;
    return deviceSize.width / widthOfDesign;
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RingQ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Dialer()
    );
  } 
}