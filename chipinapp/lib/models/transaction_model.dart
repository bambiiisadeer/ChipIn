class TransactionModel {
  final String id;
  final String membershipId;
  final String gatewayTransactionId;
  final double amount;
  final DateTime billingPeriod;
  final String status; // 'pending', 'success', 'failed'
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.membershipId,
    required this.gatewayTransactionId,
    required this.amount,
    required this.billingPeriod,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      membershipId: json['membership_id'],
      gatewayTransactionId: json['gateway_transaction_id'],
      amount: json['amount'].toDouble(),
      billingPeriod: json['billing_period'].toDate(),
      status: json['status'],
      createdAt: json['created_at'].toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'membership_id': membershipId,
      'gateway_transaction_id': gatewayTransactionId,
      'amount': amount,
      'billing_period': billingPeriod,
      'status': status,
      'created_at': createdAt,
    };
  }
}