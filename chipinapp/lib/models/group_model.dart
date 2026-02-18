class GroupModel {
  final String id;
  final String ownerId;
  final String serviceName;
  final double totalPrice;
  final int maxMembers;
  final String billingCycle;
  final bool isOneTime;
  final int paymentDueDate;
  final DateTime? endDate;
  final String promptpayNumber;
  final String inviteCode;
  final String status;

  GroupModel({
    required this.id,
    required this.ownerId,
    required this.serviceName,
    required this.totalPrice,
    required this.maxMembers,
    required this.billingCycle,
    required this.isOneTime,
    required this.paymentDueDate,
    this.endDate,
    required this.promptpayNumber,
    required this.inviteCode,
    required this.status,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      ownerId: json['owner_id'],
      serviceName: json['service_name'],
      totalPrice: json['total_price'].toDouble(),
      maxMembers: json['max_members'],
      billingCycle: json['billing_cycle'],
      isOneTime: json['is_one_time'],
      paymentDueDate: json['payment_due_date'],
      endDate: json['end_date']?.toDate(),
      promptpayNumber: json['promptpay_number'],
      inviteCode: json['invite_code'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'service_name': serviceName,
      'total_price': totalPrice,
      'max_members': maxMembers,
      'billing_cycle': billingCycle,
      'is_one_time': isOneTime,
      'payment_due_date': paymentDueDate,
      'end_date': endDate,
      'promptpay_number': promptpayNumber,
      'invite_code': inviteCode,
      'status': status,
    };
  }
}