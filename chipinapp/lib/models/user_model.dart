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

  // แปลงจาก JSON (Firestore) เป็น Object
  factory UserModel.fromJson(Map<String, dynamic> json) {
  return UserModel(
    id: json['uid'] ?? '', // AuthService ใช้ 'uid'
    username: json['username'] ?? 'User',
    email: json['email'] ?? '',
    authProvider: json['auth_provider'] ?? 'email', // AuthService ใช้ 'auth_provider'
    averageRating: (json['average_rating'] ?? 0.0).toDouble(), // AuthService ใช้ 'average_rating'
    createdAt: json['created_at'] != null 
        ? (json['created_at'] as Timestamp).toDate() 
        : DateTime.now(),
  );
}

  // แปลงจาก Object เป็น JSON เพื่อบันทึกลง Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'auth_provider': authProvider,
      'average_rating': averageRating,
      'created_at': createdAt,
    };
  }
}