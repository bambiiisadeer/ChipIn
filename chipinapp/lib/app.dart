import 'package:flutter/material.dart';
import 'route/routes.dart';

class ChipIn extends StatelessWidget {
  const ChipIn({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChipIn',
      theme: ThemeData(fontFamily: 'Poppins'),
      debugShowCheckedModeBanner: false,
      routes: AppRoutes.routes,
      initialRoute: AppRoutes.start, // บังคับเปิดแอปมาเจอหน้า Start ก่อนเสมอ
    );
  }
}