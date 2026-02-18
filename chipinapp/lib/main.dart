import 'package:flutter/material.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ไฟล์ที่ CLI สร้างให้

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // เริ่มต้นการเชื่อมต่อ Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const ChipIn());
}