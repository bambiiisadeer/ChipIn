import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Import Riverpod
import '../services/auth_service.dart'; // ✅ ดึง Provider มาใช้งาน
import 'checkslip.dart';

// ==========================================
// 🔴 LOCAL PROVIDERS (สำหรับ UI State หน้า Notification)
// ==========================================

// 1. Provider จัดการ Tab ที่ถูกเลือก
class NotificationTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int value) => state = value;
}
final notificationTabProvider = NotifierProvider<NotificationTabNotifier, int>(NotificationTabNotifier.new);

// 2. Provider ดึงข้อมูลแจ้งเตือนของผู้ใช้ (แบบ Real-time)
final notificationsStreamProvider = StreamProvider.autoDispose<List<DocumentSnapshot>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('toUserId', isEqualTo: user.uid)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
});


// ==========================================
// 🔵 MAIN PAGE
// ==========================================

class NotificationPage extends ConsumerStatefulWidget { // ✅ เปลี่ยนเป็น ConsumerStatefulWidget
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> { // ✅ เปลี่ยนเป็น ConsumerState
  final List<String> _tabs = [
    "All",
    "My Request",
    "Incoming Request",
    "Check Slip",
    "Due Date",
  ];

  Future<void> _handleApprove(DocumentSnapshot notifDoc) async {
    try {
      final currentUserId = ref.read(authStateProvider).value?.uid ?? ""; // ✅ ใช้ Riverpod ดึง UID
      if (currentUserId.isEmpty) return;

      final data = notifDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId'];
      final String requestUserId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final String originalMessage = data['message'] ?? "";

      String serviceEmail = data['serviceEmail'] ?? '';
      if (serviceEmail.isEmpty) {
        try {
          final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
          if (groupDoc.exists) {
            final groupData = groupDoc.data() as Map<String, dynamic>;
            final memberEmails = groupData['memberEmails'] as Map<String, dynamic>? ?? {};
            serviceEmail = memberEmails[requestUserId] ?? '';
          }
        } catch (e) {
          debugPrint("Error fetching memberEmails: $e");
        }
      }

      final DateTime deadline = DateTime.now().add(const Duration(hours: 24));
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final DocumentReference groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);

      batch.update(groupRef, {
        'memberStatus.$requestUserId': 'unpaid',
        'paymentDeadlines.$requestUserId': Timestamp.fromDate(deadline),
        'availableSlots': FieldValue.increment(-1),
      });

      String updatedHostMessage = originalMessage;
      if (serviceEmail.isNotEmpty) {
        updatedHostMessage = "$originalMessage with email $serviceEmail";
      }

      batch.update(notifDoc.reference, {
        'status': 'accept',
        'message': updatedHostMessage,
      });

      final String day = deadline.day.toString().padLeft(2, '0');
      final String month = deadline.month.toString().padLeft(2, '0');
      final String year = deadline.year.toString();
      final String hour = deadline.hour.toString().padLeft(2, '0');
      final String minute = deadline.minute.toString().padLeft(2, '0');
      final String dateStr = "$day-$month-$year $hour:$minute";

      final DocumentReference replyRef = FirebaseFirestore.instance.collection('notifications').doc();

      // ดึงชื่อ Host จาก ProfileProvider (ถ้าเป็นไปได้) เพื่อให้ได้ชื่อที่อัปเดตล่าสุด
      final userProfile = ref.read(userProfileProvider).value;
      final hostName = userProfile?.username ?? "Host";

      final String approveMessage = serviceEmail.isNotEmpty
          ? "$hostName has been approve your request with email $serviceEmail"
          : "$hostName has been approve your request";

      batch.set(replyRef, {
        'type': 'approved',
        'category': 'my_request',
        'toUserId': requestUserId,
        'fromUserId': currentUserId,
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message': approveMessage,
        'detail': "Please pay before $dateStr",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await batch.commit();
    } catch (e) {
      debugPrint("Error approving: $e");
    }
  }

  Future<void> _handleReject(DocumentSnapshot notifDoc) async {
    try {
      final currentUserId = ref.read(authStateProvider).value?.uid ?? ""; // ✅ ใช้ Riverpod ดึง UID
      if (currentUserId.isEmpty) return;

      final data = notifDoc.data() as Map<String, dynamic>;
      final String groupId = data['groupId'];
      final String requestUserId = data['fromUserId'];
      final String serviceName = data['service'];
      final String logo = data['logo'] ?? '';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      final DocumentReference groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'members': FieldValue.arrayRemove([requestUserId]),
        'memberStatus.$requestUserId': FieldValue.delete(),
      });

      batch.update(notifDoc.reference, {'status': 'reject'});

      final DocumentReference replyRef = FirebaseFirestore.instance.collection('notifications').doc();
      
      final userProfile = ref.read(userProfileProvider).value;
      final hostName = userProfile?.username ?? "Host";
      
      batch.set(replyRef, {
        'type': 'rejected',
        'category': 'my_request',
        'toUserId': requestUserId,
        'fromUserId': currentUserId,
        'groupId': groupId,
        'service': serviceName,
        'logo': logo,
        'message': "$hostName has been reject your request",
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
    // ✅ ดึง Tab จาก Provider
    final selectedTab = ref.watch(notificationTabProvider);

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
              onTap: () => ref.read(notificationTabProvider.notifier).set(index), // ✅ อัปเดต Tab ผ่าน Provider
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                decoration: BoxDecoration(
                  color: selectedTab == index
                      ? Colors.black
                      : const Color(0xFFEDEDED),
                  border: Border.all(
                    color: selectedTab == index
                        ? Colors.black
                        : const Color(0xFFEDEDED),
                  ),
                  borderRadius: BorderRadius.circular(25.0),
                ),
                child: Center(
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color: selectedTab == index
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
    // ✅ ดึงข้อมูล List จาก Provider
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final selectedTab = ref.watch(notificationTabProvider);

    return notificationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text("Error: $error")),
      data: (docs) {
        if (docs.isEmpty) {
          return const Center(child: Text("No notifications"));
        }

        List<DocumentSnapshot> filteredDocs = docs;

        if (selectedTab == 1) {
          filteredDocs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == 'my_request').toList();
        } else if (selectedTab == 2) {
          filteredDocs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == 'incoming_request').toList();
        } else if (selectedTab == 3) {
          filteredDocs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == 'check_slip').toList();
        } else if (selectedTab == 4) {
          filteredDocs = docs.where((d) => (d.data() as Map<String, dynamic>)['category'] == 'due_date').toList();
        }

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No notifications"));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) => _buildNotificationCard(filteredDocs[index]),
        );
      },
    );
  }

  Widget _buildNotificationCard(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final String? groupId = data['groupId'];
    final String type = data['type'] ?? '';

    const groupRelatedTypes = {
      'incoming_request',
      'approved',
      'rejected',
      'payment_received',
      'payment_due',
      'check_slip',
    };

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

    if (groupRelatedTypes.contains(type)) {
      Future.microtask(() {
        doc.reference.delete().catchError(
          (e) => debugPrint("Error cleaning orphan notif: $e"),
        );
      });
      return const SizedBox.shrink();
    }

    return _renderCardContent(doc, data);
  }

  Widget _renderCardContent(DocumentSnapshot doc, Map<String, dynamic> data) {
    final String type = data['type'] ?? '';
    final String status = data['status'] ?? 'pending';

    String timeAgo = "Just now";
    if (data['timestamp'] != null) {
      final DateTime date = (data['timestamp'] as Timestamp).toDate();
      final Duration diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) {
        timeAgo = "Just now";
      } else if (diff.inMinutes < 60) {
        timeAgo = "${diff.inMinutes} mins ago";
      } else if (diff.inHours < 24) {
        timeAgo = "${diff.inHours} hours ago";
      } else {
        timeAgo = "${diff.inDays} days ago";
      }
    }

    String? statusText;
    if (type == 'incoming_request' && status != 'pending') {
      statusText = status == 'accept' ? "Request approved" : "Request rejected";
    } else if (type == 'payment_received' &&
        (status == 'approved' || status == 'rejected')) {
      statusText = status == 'approved'
          ? "Payment approved"
          : "Payment rejected";
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
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
                ),
                const SizedBox(width: 14),
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
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (statusText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (data['price'] != null && type != 'payment_received')
                  Text(
                    data['price'],
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // ─── Approve / Reject buttons (incoming_request pending) ───
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

          // ─── Check Slip button (payment_received + pending เท่านั้น) ───
          if (type == 'payment_received' && status == 'pending') ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckSlipPage(notificationDoc: doc),
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
}