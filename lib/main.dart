// ignore_for_file: avoid_web_libraries_in_flutter, avoid_print

import 'package:scaled_app/scaled_app.dart';
import 'dialer.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'assets.dart';

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
  String username = '';
  String password = ''; 
  String extention = '';
  String callNumber = '';
  bool isAuthorize = false;

  checkAuthorize(dialerName) async {
    try {
      final response = await http.post(
        Uri.parse('https://demo.us1.ringq.ai:8443/register/calllog'),
        body: {'dialer_name': dialerName},
      );

      if (response.statusCode == 200) {
        var res = json.decode(response.body);
        if (res['result'] == "success") {
          List<String> cred = dialerName.split('@');
          
          setState(() {
            isAuthorize = true;
            extention = cred[1];
            username = cred[0];
            password = res['content']['access'];
          });
        }
      } else {
        print('Failed to send POST request. Status code: ${response.statusCode}');
      }
    } catch (e) {
      prettyLog({
        'post': '/register/calllog',
        'error': e
      });
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String currentUrl = html.window.location.href;
      Uri uri = Uri.parse(currentUrl);
      String? dialerName = uri.queryParameters["dialerName"];
      String? phoneNumber = uri.queryParameters['call'];

      dialerName != null && dialerName.isNotEmpty
        ?  await checkAuthorize(dialerName)
        : print('Dialer name is empty or null');
      callNumber = phoneNumber != null && phoneNumber.isNotEmpty
        ? phoneNumber
        : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RingQ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isAuthorize
        ? Dialer(title: 'RingQ', extensionNo: extention, username: username, password: password, callNumber: callNumber)
        : const UnauthorizedUser()
    );
  }
}

class UnauthorizedUser extends StatelessWidget {
  const UnauthorizedUser({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: backgroundColor,
    );
  }
}