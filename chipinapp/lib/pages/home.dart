import 'dart:async';
import 'package:flutter/material.dart';
import 'createnewgroup.dart' as pages;
import 'groupdetails.dart';
import 'profile.dart';
import 'marketplace.dart';
import 'hostgroupdetails.dart';
import 'hostprofile.dart';
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

  Stream<QuerySnapshot>? _groupsStream;
  Stream<QuerySnapshot>? _allGroupsStream;
  String currentUserId = "";
  String _username = "";

  StreamSubscription? _usernameSubscription;
  StreamSubscription? _authSubscription;

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
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        setState(() {
          currentUserId = user.uid;
          _groupsStream = _createQueryStream();
          _allGroupsStream = _createAllMemberStream();
        });
        _usernameSubscription?.cancel();
        _listenToUsername();
      } else {
        _usernameSubscription?.cancel();
        setState(() {
          currentUserId = "";
          _username = "";
          _groupsStream = null;
          _allGroupsStream = null;
        });
      }
    });
  }

  void _listenToUsername() {
    if (currentUserId.isEmpty) return;
    _usernameSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data() as Map<String, dynamic>;
            setState(() {
              _username = data['username'] ?? data['email'] ?? "";
            });
          }
        });
  }

  @override
  void dispose() {
    _usernameSubscription?.cancel();
    _authSubscription?.cancel();
    _inviteCodeController.dispose();
    super.dispose();
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

  Stream<QuerySnapshot> _createAllMemberStream() {
    if (currentUserId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: currentUserId)
        .snapshots();
  }

  void _onFilterChanged(int index) {
    setState(() {
      _filterIndex = index;
      if (currentUserId.isNotEmpty) {
        _groupsStream = _createQueryStream();
      }
    });
  }

  Future<void> _joinGroup(
    BuildContext context,
    StateSetter setModalState,
  ) async {
    String code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;
    setModalState(() => _isJoining = true);
    final navigator = Navigator.of(context);
    try {
      final QuerySnapshot query = await FirebaseFirestore.instance
          .collection('groups')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        if (mounted) setModalState(() => _isJoining = false);
        return;
      }
      final DocumentSnapshot groupDoc = query.docs.first;
      final Map<String, dynamic> data = groupDoc.data() as Map<String, dynamic>;
      String hostName = "Unknown";
      try {
        DocumentSnapshot hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['createdBy'])
            .get();
        if (hostDoc.exists) {
          final hostData = hostDoc.data() as Map<String, dynamic>;
          hostName = hostData['username'] ?? hostData['email'] ?? "Unknown";
        }
      } catch (e) {
        debugPrint(e.toString());
      }
      if (!mounted) return;
      final Map<String, dynamic> groupItem = {
        'id': groupDoc.id,
        'name': data['serviceName'] ?? 'Unknown',
        'logo': data['logo'] ?? 'assets/images/netflix.png',
        'host': hostName,
        'createdBy': data['createdBy'] ?? '',
        'price': data['price']?.toString() ?? '0',
        'duration':
            '${data['duration']?.toString() ?? '-'} ${data['durationUnit']?.toString() ?? ''}'
                .trim(),
        'availableSlots': data['availableSlots'] ?? 0,
        'members': data['members'] ?? [],
      };
      navigator.pop();
      _inviteCodeController.clear();
      _showSubscriptionRequestModal(this.context, groupItem);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setModalState(() => _isJoining = false);
    }
  }

  Future<void> _sendJoinRequest(
    BuildContext context,
    Map<String, dynamic> item,
    String serviceEmail,
  ) async {
    final navigator = Navigator.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final List<dynamic> members = item['members'] ?? [];
    if (members.contains(user.uid)) return;
    if ((item['availableSlots'] ?? 0) <= 0) return;
    try {
      final String currentUserName = _username.isNotEmpty
          ? _username
          : "Unknown";
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final DocumentReference groupRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(item['id']);
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([user.uid]),
        'memberStatus.${user.uid}': 'pending',
        'memberNames.${user.uid}': currentUserName,
        'memberEmails.${user.uid}': serviceEmail,
      });
      final DocumentReference notifRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'incoming_request',
        'category': 'incoming_request',
        'toUserId': item['createdBy'],
        'fromUserId': user.uid,
        'fromUserName': currentUserName,
        'service': item['name'],
        'logo': item['logo'],
        'groupId': item['id'],
        'price': "${item['price']} THB",
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'message': "$currentUserName want to join your group",
        'serviceEmail': serviceEmail,
      });
      await batch.commit();
      navigator.pop();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _showSubscriptionRequestModal(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final TextEditingController emailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
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
                Row(
                  children: [
                    Container(
                      width: 37.0,
                      height: 37.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage(item['logo']),
                          fit: BoxFit.cover,
                        ),
                        border: Border.all(
                          color: const Color.fromARGB(255, 242, 242, 242),
                          width: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        item['name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HostProfilePage(
                              hostUserId: item['createdBy'],
                              hostUsername: item['host'],
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "See reviews",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.underline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow("By", item['host']),
                const Divider(height: 1),
                _buildInfoRow("Price", "${item['price']} THB"),
                const Divider(height: 1),
                _buildInfoRow("Duration", item['duration']),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Service Email",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          hintText: "Email",
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (emailController.text.isNotEmpty) {
                        final email = emailController.text.trim();
                        Navigator.pop(context);
                        _sendJoinRequest(this.context, item, email);
                        _showSuccessModal(this.context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      "Send Request",
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
  }

  void _showSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
              const SizedBox(height: 30),
              Container(
                width: 55.0,
                height: 55.0,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                "Success !",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your request has been sent,",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const Text(
                "Please wait for the host to approve.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    "Done",
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
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 92, 94, 98),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
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
                                  minimumSize: const Size(50, 47),
                                  padding: EdgeInsets.zero,
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
                                    : const Icon(Icons.search, size: 24),
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
                          if (result != null) {
                            setState(() {
                              if (currentUserId.isNotEmpty) {
                                _groupsStream = _createQueryStream();
                                _allGroupsStream = _createAllMemberStream();
                              }
                            });
                          }
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
              title: Text(
                "Hi, $_username",
                style: const TextStyle(fontSize: 14.0, color: Colors.black),
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
    if (currentUserId.isEmpty || _allGroupsStream == null) {
      return ListView(
        padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 100),
        children: [
          _buildTotalDueCard(0.0),
          const SizedBox(height: 30.0),
          const Text(
            "Your Subscription",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20.0),
          _buildFilterBar(),
          const SizedBox(height: 15.0),
          const Center(child: Text("Please login to view subscriptions")),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _allGroupsStream,
      builder: (context, allSnapshot) {
        double totalDue = 0.0;
        if (allSnapshot.hasData && allSnapshot.data != null) {
          for (var doc in allSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final memberStatus =
                data['memberStatus'] as Map<String, dynamic>? ?? {};
            String statusToShow;
            if (data['createdBy'] == currentUserId) {
              statusToShow = 'paid';
            } else {
              statusToShow =
                  memberStatus[currentUserId] ?? (data['status'] ?? 'unpaid');
            }
            if (statusToShow.toLowerCase() == 'unpaid') {
              final price = data['price'];
              if (price != null)
                totalDue += double.tryParse(price.toString()) ?? 0.0;
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, bottom: 100),
          children: [
            _buildTotalDueCard(totalDue),
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No subscriptions found"),
                    ),
                  );
                }

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
                      Map<String, dynamic> memberStatus =
                          sub['memberStatus'] ?? {};
                      statusToShow =
                          memberStatus[currentUserId] ??
                          (sub['status'] ?? "Unpaid");
                    }

                    String timerText = "";
                    String displayDate = "-";

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
      },
    );
  }

  Widget _buildTotalDueCard(double totalDue) {
    String formattedAmount = totalDue.toStringAsFixed(2);
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
                children: [
                  Text(
                    formattedAmount,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 40.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
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
      case "checking":
        statusBgColor = const Color(0xFFDBEEFF);
        statusTextColor = const Color(0xFF1A7FD4);
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
