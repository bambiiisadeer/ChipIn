import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ เพิ่ม Riverpod
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart'; // ✅ ดึง Provider มาใช้

// ✅ เปลี่ยนเป็น ConsumerStatefulWidget
class CheckSlipPage extends ConsumerStatefulWidget {
  final DocumentSnapshot notificationDoc;

  const CheckSlipPage({super.key, required this.notificationDoc});

  @override
  ConsumerState<CheckSlipPage> createState() => _CheckSlipPageState();
}

class _CheckSlipPageState extends ConsumerState<CheckSlipPage> {
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    setState(() => _isProcessing = true);

    try {
      final data = widget.notificationDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId'];
      final String memberId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      // ✅ 1. ดึงชื่อปัจจุบันของโฮสต์จาก Provider
      final userProfile = ref.read(userProfileProvider).value;
      final String currentUserName = userProfile?.username ?? 'Host';
      final String currentUserId = ref.read(authStateProvider).value?.uid ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // อัปเดตสถานะ member ใน Group เป็น 'paid'
      final DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);
      batch.update(groupRef, {
        'memberStatus.$memberId': 'paid',
        'paymentDeadlines.$memberId': FieldValue.delete(),
      });

      // อัปเดต Notification เดิม
      batch.update(widget.notificationDoc.reference, {'status': 'approved'});

      // ✅ 2. สร้าง Notification ใหม่แจ้ง Member โดยใช้ชื่อจริง
      final DocumentReference replyRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(replyRef, {
        'type': 'payment_approved',
        'category': 'my_request',
        'toUserId': memberId,
        'fromUserId': currentUserId,
        'fromUserName':
            currentUserName, // ✅ ใส่ field นี้เพื่อให้ profile.dart ตามแก้ชื่อได้
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message':
            "$currentUserName has approved your payment", // ✅ ใช้ชื่อแทนคำว่า Host
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error approving: $e");
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

      // ✅ 1. ดึงชื่อปัจจุบันของโฮสต์จาก Provider
      final userProfile = ref.read(userProfileProvider).value;
      final String currentUserName = userProfile?.username ?? 'Host';
      final String currentUserId = ref.read(authStateProvider).value?.uid ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      final DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);

      batch.update(groupRef, {'memberStatus.$memberId': 'unpaid'});
      batch.update(widget.notificationDoc.reference, {'status': 'rejected'});

      final DocumentReference replyRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(replyRef, {
        'type': 'payment_rejected',
        'category': 'my_request',
        'toUserId': memberId,
        'fromUserId': currentUserId,
        'fromUserName': currentUserName, // ✅ ใส่ field นี้
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message':
            "$currentUserName has rejected your payment. Please submit again.", // ✅ ใช้ชื่อจริง
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error rejecting: $e");
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
    final String slipBase64 = data['slipBase64'] ?? '';

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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
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

                    SizedBox(
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: slipBase64.isNotEmpty
                            ? Image.memory(
                                base64Decode(slipBase64),
                                fit: BoxFit.fitWidth,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
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
