import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CheckSlipPage extends StatefulWidget {
  final DocumentSnapshot notificationDoc;

  const CheckSlipPage({super.key, required this.notificationDoc});

  @override
  State<CheckSlipPage> createState() => _CheckSlipPageState();
}

class _CheckSlipPageState extends State<CheckSlipPage> {
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    setState(() => _isProcessing = true);

    try {
      final data = widget.notificationDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId'];
      final String memberId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. อัปเดตสถานะ member ใน Group เป็น 'paid'
      final DocumentReference groupRef =
          FirebaseFirestore.instance.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'memberStatus.$memberId': 'paid',
        'paymentDeadlines.$memberId': FieldValue.delete(),
      });

      // 2. อัปเดต Notification เดิม: เปลี่ยนสถานะเป็น approved
      batch.update(widget.notificationDoc.reference, {'status': 'approved'});

      // 3. สร้าง Notification ใหม่แจ้ง Member ว่า payment approved
      final DocumentReference replyRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(replyRef, {
        'type': 'payment_approved',
        'category': 'my_request',
        'toUserId': memberId,
        'fromUserId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message': "Host has approved your payment",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment approved successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isProcessing = true);

    try {
      final data = widget.notificationDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId'];
      final String memberId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. เปลี่ยนสถานะกลับเป็น 'unpaid'
      final DocumentReference groupRef =
          FirebaseFirestore.instance.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'memberStatus.$memberId': 'unpaid',
      });

      // 2. อัปเดต Notification เดิม: เปลี่ยนสถานะเป็น rejected
      batch.update(widget.notificationDoc.reference, {'status': 'rejected'});

      // 3. สร้าง Notification ใหม่แจ้ง Member ว่า payment rejected
      final DocumentReference replyRef =
          FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(replyRef, {
        'type': 'payment_rejected',
        'category': 'my_request',
        'toUserId': memberId,
        'fromUserId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message': "Host has rejected your payment. Please submit again.",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment rejected")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.notificationDoc.data() as Map<String, dynamic>;
    final String senderName = data['sender'] ?? 'Member';
    final String serviceName = data['service'] ?? 'Unknown Service';
    final String logo = data['logo'] ?? 'assets/images/netflix.png';
    final String price = data['price'] ?? '0 THB';
    final String slipUrl = data['slipUrl'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Payment Verification",
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Verify username
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black,
                        ),
                        children: [
                          const TextSpan(
                            text: "Verify ",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          TextSpan(text: senderName),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Service and Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Service Logo
                            Container(
                              width: 37.0,
                              height: 37.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1.0,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  logo,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              serviceName,
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // Payment Slip Image
                    SizedBox(
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: slipUrl.isNotEmpty
                            ? Image.asset(
                                slipUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.broken_image, size: 50),
                                          SizedBox(height: 8),
                                          Text('Slip image not available'),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Text('No slip uploaded'),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: 30.0,
            ),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                // Reject Button
                Expanded(
                  child: SizedBox(
                    height: 47,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _handleReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black, width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              "Reject",
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 15),

                // Approve Button
                Expanded(
                  child: SizedBox(
                    height: 47,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Approve",
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}