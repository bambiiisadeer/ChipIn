import 'package:flutter/material.dart';
import 'createnewgroup.dart' as pages;
import 'groupdetails.dart';
import 'profile.dart';
import 'marketplace.dart';
import 'hostgroupdetails.dart';
import 'notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _filterIndex = 0;
  int _bottomNavIndex = 0;

  late Stream<QuerySnapshot> _groupsStream;
  late String currentUserId;

  final TextEditingController _inviteCodeController = TextEditingController();
  bool _isJoining = false;

  final List<String> _menuItems = ["All", "Host", "Member"];

  final List<Map<String, dynamic>> _navItems = [
    {"icon": Icons.home_sharp, "label": "Home"},
    {"icon": Icons.shopping_cart_sharp, "label": "Market"},
    {"icon": Icons.notifications, "label": "Notification"},
    {"icon": Icons.person_sharp, "label": "Profile"},
  ];

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    _groupsStream = _createQueryStream();
  }

  Stream<QuerySnapshot> _createQueryStream() {
    Query query = FirebaseFirestore.instance.collection('groups');

    if (currentUserId.isEmpty) return const Stream.empty();

    if (_filterIndex == 0) {
      query = query.where('members', arrayContains: currentUserId);
    } else if (_filterIndex == 1) {
      query = query.where('createdBy', isEqualTo: currentUserId);
    } else if (_filterIndex == 2) {
      query = query.where('members', arrayContains: currentUserId);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  void _onFilterChanged(int index) {
    setState(() {
      _filterIndex = index;
      _groupsStream = _createQueryStream();
    });
  }

  Future<void> _joinGroup(
    BuildContext context,
    StateSetter setModalState,
  ) async {
    String code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;

    setModalState(() => _isJoining = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. ดึงชื่อ username จริงจากฐานข้อมูล
      String currentUserName = "Unknown";
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          currentUserName =
              userData['username'] ?? userData['email'] ?? "Unknown";
        }
      } catch (e) {
        print(e);
      }

      // 2. ค้นหากลุ่ม
      final QuerySnapshot query = await FirebaseFirestore.instance
          .collection('groups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final DocumentSnapshot groupDoc = query.docs.first;
      final Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = data['members'] ?? [];
      final int availableSlots = data['availableSlots'] ?? 0;

      if (members.contains(user.uid)) return;
      if (availableSlots <= 0) return;

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 3. บันทึกข้อมูลการ Join (Pending)
      DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupDoc.id);
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([user.uid]),
        'memberStatus.${user.uid}': 'pending',
        'memberNames.${user.uid}': currentUserName,
      });

      // 4. แจ้งเตือน Host
      DocumentReference notifRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'incoming_request',
        'category': 'incoming_request',
        'toUserId': data['createdBy'],
        'fromUserId': user.uid,
        'fromUserName': currentUserName,
        'service': data['serviceName'],
        'logo': data['logo'],
        'groupId': groupDoc.id,
        'price': "${data['price']} THB",
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'message': "$currentUserName want to join your group",
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // ปิดแค่ Modal เงียบๆ
        _inviteCodeController.clear();
      }
    } catch (e) {
      //
    } finally {
      if (mounted) setModalState(() => _isJoining = false);
    }
  }

  void _showAddSubscriptionModal(BuildContext context) {
    _inviteCodeController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Add Subscription",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Enter Invite Code",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextField(
                                    controller: _inviteCodeController,
                                    decoration: const InputDecoration(
                                      hintText: "e.g. ABC-1234",
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _isJoining
                                    ? null
                                    : () => _joinGroup(context, setModalState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  minimumSize: const Size(80, 47),
                                ),
                                child: _isJoining
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Join",
                                        style: TextStyle(
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.grey[400], thickness: 1),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "or",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.grey[400], thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 47,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const pages.CreateNewGroupPage(),
                            ),
                          );
                          if (result != null)
                            setState(
                              () => _groupsStream = _createQueryStream(),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Create New Group",
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _getCurrentPage() {
    switch (_bottomNavIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return MarketplacePage();
      case 2:
        return NotificationPage();
      case 3:
        return const ProfilePage();
      default:
        return _buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _bottomNavIndex == 0
          ? AppBar(
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                "Hi, Poon",
                style: TextStyle(fontSize: 14.0, color: Colors.black),
                textAlign: TextAlign.left,
              ),
            )
          : null,
      body: _getCurrentPage(),
      floatingActionButton: Visibility(
        visible: _bottomNavIndex == 0,
        child: FloatingActionButton(
          onPressed: () => _showAddSubscriptionModal(context),
          backgroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 2,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 0.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 57.0,
            padding: EdgeInsets.fromLTRB(
              _bottomNavIndex == 0 ? 5.0 : 25.0,
              5.5,
              _bottomNavIndex == 3 ? 5.0 : 25.0,
              5.0,
            ),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 30, 30, 30),
              borderRadius: BorderRadius.circular(30.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_navItems.length, (index) {
                bool isSelected = _bottomNavIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _bottomNavIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    height: 53.0,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color.fromARGB(255, 62, 63, 66)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: isSelected
                        ? const EdgeInsets.symmetric(horizontal: 20.0)
                        : const EdgeInsets.symmetric(horizontal: 0.0),
                    child: Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_navItems[index]['icon'], color: Colors.white),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: SizedBox(
                              width: isSelected ? null : 0.0,
                              child: Padding(
                                padding: isSelected
                                    ? const EdgeInsets.only(
                                        left: 6.0,
                                        bottom: 2.0,
                                      )
                                    : EdgeInsets.zero,
                                child: Text(
                                  _navItems[index]['label'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 100),
      children: [
        _buildTotalDueCard(),
        const SizedBox(height: 30.0),
        const Text(
          "Your Subscription",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 20.0),
        _buildFilterBar(),
        const SizedBox(height: 15.0),
        StreamBuilder<QuerySnapshot>(
          stream: _groupsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(child: Text("Error: ${snapshot.error}"));
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("No subscriptions found"),
                ),
              );

            var docs = snapshot.data!.docs;
            if (_filterIndex == 2) {
              docs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['createdBy'] != currentUserId;
              }).toList();
            }

            return Column(
              children: docs.map((DocumentSnapshot document) {
                Map<String, dynamic> sub =
                    document.data()! as Map<String, dynamic>;
                sub['id'] = document.id;

                String statusToShow = "Unpaid";
                if (sub['createdBy'] == currentUserId) {
                  statusToShow = "Paid";
                } else {
                  Map<String, dynamic> memberStatus = sub['memberStatus'] ?? {};
                  statusToShow =
                      memberStatus[currentUserId] ??
                      (sub['status'] ?? "Unpaid");
                }

                String timerText = "";
                String displayDate = "-";

                // Pending Logic: End Date "-"
                if (statusToShow.toLowerCase() != 'pending') {
                  if (sub['endDate'] != null) {
                    DateTime date = (sub['endDate'] as Timestamp).toDate();
                    List<String> months = [
                      "Jan",
                      "Feb",
                      "Mar",
                      "Apr",
                      "May",
                      "Jun",
                      "Jul",
                      "Aug",
                      "Sep",
                      "Oct",
                      "Nov",
                      "Dec",
                    ];
                    displayDate = "${date.day} ${months[date.month - 1]}.";
                  }
                }

                // Timer Logic for Unpaid
                if (statusToShow.toLowerCase() == 'unpaid') {
                  Map<String, dynamic> deadlines =
                      sub['paymentDeadlines'] ?? {};
                  Timestamp? deadlineTs = deadlines[currentUserId];
                  if (deadlineTs != null) {
                    DateTime deadline = deadlineTs.toDate();
                    Duration diff = deadline.difference(DateTime.now());
                    timerText = diff.isNegative
                        ? "Expired"
                        : "Please pay within ${diff.inHours} h ${diff.inMinutes % 60} m";
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: GestureDetector(
                    onTap: () {
                      if (statusToShow.toLowerCase() == 'pending') return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              sub['createdBy'] == currentUserId
                              ? HostGroupDetailsPage(subscription: sub)
                              : GroupDetailsPage(subscription: sub),
                        ),
                      );
                    },
                    child: SubscriptionCard(
                      name: sub['serviceName'] ?? "Unknown",
                      price: sub['price'].toString(),
                      logoPath: sub['logo'] ?? "assets/images/netflix.png",
                      endDate: displayDate,
                      status: statusToShow,
                      timerText: timerText,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTotalDueCard() {
    return Container(
      height: 110.0,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 237, 237, 237),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              const Text("Total due"),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Text(
                    "0.00",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 40.0,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "THB",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 24.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 47.0,
      width: double.maxFinite,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 237, 237, 237),
        borderRadius: BorderRadius.circular(24.0),
      ),
      padding: const EdgeInsets.all(5.0),
      child: Row(
        children: List.generate(_menuItems.length, (index) {
          bool isSelected = _filterIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onFilterChanged(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: Center(
                  child: Text(
                    _menuItems[index],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : const Color.fromARGB(255, 92, 94, 98),
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SubscriptionCard extends StatelessWidget {
  final String name;
  final String price;
  final String logoPath;
  final String endDate;
  final String status;
  final String timerText;

  const SubscriptionCard({
    super.key,
    required this.name,
    required this.price,
    required this.logoPath,
    required this.endDate,
    required this.status,
    this.timerText = "",
  });

  @override
  Widget build(BuildContext context) {
    Color statusBgColor;
    Color statusTextColor;
    String statusText = "• ${status[0].toUpperCase()}${status.substring(1)}";

    switch (status.toLowerCase()) {
      case "paid":
        statusBgColor = const Color.fromARGB(52, 65, 163, 19);
        statusTextColor = const Color.fromARGB(255, 65, 163, 19);
        break;
      case "pending":
        statusBgColor = const Color(0xFFFFF9DB);
        statusTextColor = const Color(0xFFEAB308);
        break;
      default:
        statusBgColor = const Color.fromARGB(255, 255, 214, 214);
        statusTextColor = const Color.fromARGB(255, 177, 6, 15);
        break;
    }

    Widget mainCardContent = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 45.0,
          height: 45.0,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF2F2F2), width: 1.0),
            image: DecorationImage(image: AssetImage(logoPath)),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  Text(
                    "$price THB",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16.0,
                    ),
                  ),
                ],
              ),
              (status.toLowerCase() == "unpaid")
                  ? const Spacer()
                  : const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "End Date: $endDate",
                    style: const TextStyle(fontSize: 12.0),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 2.0,
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(fontSize: 12.0, color: statusTextColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (status.toLowerCase() == "unpaid" && timerText.isNotEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: const Color(0xFFE3E3E3), width: 1.0),
              ),
              padding: const EdgeInsets.all(15.0),
              child: IntrinsicHeight(child: mainCardContent),
            ),
            Transform.translate(
              offset: const Offset(0, -5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15.0, 15.0, 15.0, 5.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled_rounded,
                      size: 16.0,
                      color: Color(0xFF5C5E62),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      timerText,
                      style: const TextStyle(
                        color: Color(0xFF5C5E62),
                        fontSize: 12.0,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      "Pay now",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.0,
                        color: Colors.black,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(15.0),
        height: 84.0,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: const Color(0xFFE3E3E3), width: 1.0),
        ),
        child: mainCardContent,
      );
    }
  }
}
