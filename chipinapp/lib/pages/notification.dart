import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'checkslip.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _selectedTab = 0;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  final List<String> _tabs = [
    "All",
    "My Request",
    "Incoming Request",
    "Check Slip",
    "Due Date",
  ];

  Future<void> _handleApprove(DocumentSnapshot notifDoc) async {
    try {
      final data = notifDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId']; // ✅ consistent
      final String requestUserId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final DateTime deadline = DateTime.now().add(const Duration(hours: 24));

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. อัปเดต Group: เพิ่มสถานะ member + ลด slot
      final DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);
      batch.update(groupRef, {
        'memberStatus.$requestUserId': 'unpaid',
        'paymentDeadlines.$requestUserId': Timestamp.fromDate(deadline),
        'availableSlots': FieldValue.increment(-1),
      });

      // 2. อัปเดต Notification เดิม: เปลี่ยนสถานะเป็น accept
      batch.update(notifDoc.reference, {'status': 'accept'});

      // 3. สร้าง Notification ใหม่แจ้ง Member ว่าได้รับการอนุมัติ
      final String day = deadline.day.toString().padLeft(2, '0');
      final String month = deadline.month.toString().padLeft(2, '0');
      final String year = deadline.year.toString();
      final String hour = deadline.hour.toString().padLeft(2, '0');
      final String minute = deadline.minute.toString().padLeft(2, '0');
      final String dateStr = "$day-$month-$year $hour:$minute";

      final DocumentReference replyRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();

      batch.set(replyRef, {
        'type': 'approved',
        'category': 'my_request',
        'toUserId': requestUserId,
        'fromUserId': currentUserId,
        'groupId': groupId, // ✅ เพิ่ม groupId ทุก notification
        'service': serviceName,
        'logo': logo,
        'message': "Host has been approve your request",
        'detail': "Please pay before $dateStr",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _handleReject(DocumentSnapshot notifDoc) async {
    try {
      final data = notifDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId']; // ✅ consistent
      final String requestUserId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. ลบ member ออกจาก Group
      final DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId);
      batch.update(groupRef, {
        'members': FieldValue.arrayRemove([requestUserId]),
        'memberStatus.$requestUserId': FieldValue.delete(),
      });

      // 2. อัปเดต Notification เดิม: เปลี่ยนสถานะเป็น reject
      batch.update(notifDoc.reference, {'status': 'reject'});

      // 3. สร้าง Notification ใหม่แจ้ง Member ว่าถูก reject
      final DocumentReference replyRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(replyRef, {
        'type': 'rejected',
        'category': 'my_request',
        'toUserId': requestUserId,
        'fromUserId': currentUserId, // ✅ เพิ่ม fromUserId ที่หายไป
        'groupId': groupId, // ✅ เพิ่ม groupId ทุก notification
        'service': serviceName,
        'logo': logo,
        'message': "Host has been reject your request",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
    } catch (e) {
      debugPrint("Error rejecting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Notification",
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabSection(),
          const SizedBox(height: 20),
          Expanded(child: _buildNotificationList()),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return SizedBox(
      height: 40.0,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                decoration: BoxDecoration(
                  color: _selectedTab == index
                      ? Colors.black
                      : const Color(0xFFEDEDED),
                  border: Border.all(
                    color: _selectedTab == index
                        ? Colors.black
                        : const Color(0xFFEDEDED),
                  ),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: Center(
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color: _selectedTab == index
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.w400,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList() {
    final Query query = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: currentUserId)
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No notifications"));
        }

        var docs = snapshot.data!.docs;

        // Filter ตาม tab
        if (_selectedTab == 1) {
          docs = docs.where((d) => d['category'] == 'my_request').toList();
        } else if (_selectedTab == 2) {
          docs = docs
              .where((d) => d['category'] == 'incoming_request')
              .toList();
        } else if (_selectedTab == 3) {
          docs = docs.where((d) => d['category'] == 'check_slip').toList();
        } else if (_selectedTab == 4) {
          docs = docs.where((d) => d['category'] == 'due_date').toList();
        }

        if (docs.isEmpty) {
          return const Center(child: Text("No notifications in this category"));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          itemCount: docs.length,
          itemBuilder: (context, index) => _buildNotificationCard(docs[index]),
        );
      },
    );
  }

  /// เช็คว่า Group ยังอยู่ไหม ถ้าไม่อยู่ให้ลบ Notification ทิ้งอัตโนมัติ
  Widget _buildNotificationCard(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final String? groupId = data['groupId'];
    final String type = data['type'] ?? '';

    // Type ที่ต้องมี groupId เสมอ
    const groupRelatedTypes = {
      'incoming_request',
      'approved',
      'rejected',
      'payment_received',
      'payment_due',
      'check_slip',
    };

    // ✅ CASE 1: มี groupId → เช็คว่ากลุ่มยังอยู่ไหม
    if (groupId != null && groupId.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          // กลุ่มหายไปแล้ว → ลบ notification ทิ้ง
          if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
            Future.microtask(() {
              doc.reference.delete().catchError(
                (e) => debugPrint("Error cleaning notif: $e"),
              );
            });
            return const SizedBox.shrink();
          }
          return _renderCardContent(doc, data);
        },
      );
    }

    // ✅ CASE 2: ไม่มี groupId แต่เป็น type ที่ควรมี → โค้ดเก่า, ลบทิ้ง
    if (groupRelatedTypes.contains(type)) {
      Future.microtask(() {
        doc.reference.delete().catchError(
          (e) => debugPrint("Error cleaning orphan notif: $e"),
        );
      });
      return const SizedBox.shrink();
    }

    // ✅ CASE 3: ไม่มี groupId และไม่ใช่ group-related → system notification แสดงปกติ
    return _renderCardContent(doc, data);
  }

  Widget _renderCardContent(DocumentSnapshot doc, Map<String, dynamic> data) {
    final String type = data['type'] ?? '';
    final String status = data['status'] ?? 'pending';

    String timeAgo = "Just now";
    if (data['timestamp'] != null) {
      final DateTime date = (data['timestamp'] as Timestamp).toDate();
      final Duration diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) {
        timeAgo = "${diff.inMinutes} mins ago";
      } else if (diff.inHours < 24) {
        timeAgo = "${diff.inHours} hours ago";
      } else {
        timeAgo = "${diff.inDays} days ago";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15.0),
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE3E2E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage(
                      data['logo'] ?? 'assets/images/netflix.png',
                    ),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: const Color(0xFFF2F2F2)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['service'] ?? 'Unknown Service',
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['message'] ?? '',
                      style: const TextStyle(fontSize: 14.0),
                    ),
                    if (data['detail'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        data['detail'],
                        style: const TextStyle(fontSize: 14.0),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (type == 'incoming_request' && status != 'pending')
                _buildStatusBadge(status)
              else if (data['price'] != null)
                Text(
                  data['price'],
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),

          // Approve / Reject buttons
          if (type == 'incoming_request' && status == 'pending') ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _handleApprove(doc),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Approve",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _handleReject(doc),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        "Reject",
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
          ],

          // Check Slip button
          if (type == 'payment_received') ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  // ✅ ส่ง data ของแจ้งเตือนนี้ไปที่ CheckSlipPage
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckSlipPage(
                        notificationData: data,
                      ), // ส่ง data ไปที่นี่
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "Check Slip",
                  style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color = status == 'accept'
        ? const Color(0xFF41A313)
        : const Color(0xFFB1060F);
    final Color bgColor = status == 'accept'
        ? const Color.fromARGB(52, 65, 163, 19)
        : const Color.fromARGB(255, 255, 214, 214);
    final String text = status == 'accept' ? "Accepted" : "Rejected";
    final IconData icon = status == 'accept' ? Icons.check : Icons.close;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.0, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12.0, color: color)),
        ],
      ),
    );
  }
}
