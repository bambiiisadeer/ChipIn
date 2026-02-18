import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // ฟังก์ชันเก็บสถานะ Login
  static Future<void> saveLoginStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', status);
  }

  // ฟังก์ชันตรวจสอบสถานะ Login เมื่อแอปเปิด
  static Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}