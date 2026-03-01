import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username;
  final String email;
  final String authProvider;
  final double averageRating;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.authProvider,
    this.averageRating = 0.0,
    required this.createdAt,
  });

  // ✅ เปลี่ยนชื่อเป็น fromFirestore หรือจะเพิ่มไว้ทั้ง 2 ชื่อเลยก็ได้ครับ
  // ผมปรับให้รองรับข้อมูลจาก AuthService (uid) และ Firestore (created_at) ให้เป๊ะขึ้น
  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    return UserModel(
      id: json['uid'] ?? json['id'] ?? '', // รองรับทั้ง 'uid' และ 'id'
      username: json['username'] ?? 'User',
      email: json['email'] ?? '',
      authProvider: json['auth_provider'] ?? 'email',
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] != null 
          ? (json['created_at'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // เผื่อคุณยังอยากใช้ชื่อเดิมในส่วนอื่นของโปรเจกต์
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel.fromFirestore(json);

  Map<String, dynamic> toJson() {
    return {
      'uid': id, // ใช้ 'uid' เพื่อให้ตรงกับในฐานข้อมูลที่คุณใช้อยู่
      'username': username,
      'email': email,
      'auth_provider': authProvider,
      'average_rating': averageRating,
      'created_at': createdAt,
    };
  }
}