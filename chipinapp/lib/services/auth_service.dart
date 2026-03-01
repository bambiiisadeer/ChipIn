import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ เพิ่ม Riverpod
import '../models/user_model.dart';
import '../local_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ==========================================
// 🔴 RIVERPOD PROVIDERS
// ==========================================

// 1. Provider สำหรับเข้าถึง AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// 2. StreamProvider ติดตามสถานะ Login (Firebase User)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 3. StreamProvider สำหรับดึงข้อมูลโปรไฟล์ผู้ใช้จาก Firestore (User Model)
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  
  // ถ้ายังไม่ login หรือกำลังโหลด ให้ส่ง null
  final user = authState.value;
  if (user == null) return Stream.value(null);

  // เชื่อมต่อ Stream กับ Firestore Document ของ User คนนี้
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        if (snapshot.exists) {
          return UserModel.fromFirestore(snapshot.data() as Map<String, dynamic>);
        }
        return null;
      });
});

// ==========================================
// 🔵 AUTH SERVICE CLASS
// ==========================================

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ฟังก์ชันกลางสำหรับจัดการข้อมูล User ---
  Future<void> _updateUserData(
    User user,
    String provider, {
    String? customUsername,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);

    final docSnapshot = await userRef.get();
    final existingData = docSnapshot.exists
        ? docSnapshot.data() as Map<String, dynamic>
        : null;

    final String usernameToSave =
        (existingData != null &&
            existingData['username'] != null &&
            existingData['username'].toString().isNotEmpty)
        ? existingData['username']
        : customUsername ??
              user.displayName ??
              user.email?.split('@')[0] ??
              'User';

    final double averageRatingToSave =
        (existingData != null && existingData['average_rating'] != null)
        ? (existingData['average_rating'] as num).toDouble()
        : 0.0;

    final int reviewCountToSave =
        (existingData != null && existingData['review_count'] != null)
        ? (existingData['review_count'] as num).toInt()
        : 0;

    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'username': usernameToSave,
      'auth_provider': provider,
      'created_at': FieldValue.serverTimestamp(),
      'average_rating': averageRatingToSave,
      'review_count': reviewCountToSave,
    }, SetOptions(merge: true));
  }

  // ฟังก์ชันสมัครสมาชิก
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _updateUserData(result.user!, 'email', customUsername: username);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ฟังก์ชันเข้าสู่ระบบ
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await LocalStorage.saveLoginStatus(true);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _updateUserData(userCredential.user!, 'google');
      return userCredential;
    } catch (e) {
      return null;
    }
  }

  // ออกจากระบบ
  Future<void> logout() async {
    await _auth.signOut();
    await LocalStorage.saveLoginStatus(false);
  }
}