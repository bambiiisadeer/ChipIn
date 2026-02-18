class MembershipModel {
  final String id;
  final String groupId;
  final String userId;
  final String role; // 'owner' หรือ 'member'
  final String membershipStatus; // 'pending', 'active', 'rejected'
  final String paymentStatus; // 'unpaid', 'pending_verification', 'paid'
  final DateTime joinedAt;

  MembershipModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.membershipStatus,
    required this.paymentStatus,
    required this.joinedAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id: json['id'],
      groupId: json['group_id'],
      userId: json['user_id'],
      role: json['role'],
      membershipStatus: json['membership_status'],
      paymentStatus: json['payment_status'],
      joinedAt: json['joined_at'].toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'role': role,
      'membership_status': membershipStatus,
      'payment_status': paymentStatus,
      'joined_at': joinedAt,
    };
  }
}