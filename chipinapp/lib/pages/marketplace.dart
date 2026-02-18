import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hostprofile.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  int _selectedFilter = 0;
  String _selectedDuration = "All";
  String _selectedSort = "Rating";

  final List<String> _filters = [
    "All",
    "Netflix",
    "Spotify",
    "Youtube",
    "Disney+",
  ];

  final List<String> _durationOptions = ["All", "Days", "Months", "Years"];
  final List<String> _sortOptions = ["Rating", "Price", "Duration"];

  List<Map<String, dynamic>> _marketplaceItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMarketplaceItems();
  }

  // ------------------------------------------------------------------ //
  //  DATA FETCHING
  // ------------------------------------------------------------------ //

  Future<void> _fetchMarketplaceItems() async {
    setState(() => _isLoading = true);

    try {
      final groupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('showInMarket', isEqualTo: true)
          .get();

      if (groupsSnapshot.docs.isEmpty) {
        setState(() {
          _marketplaceItems = [];
          _isLoading = false;
        });
        return;
      }

      final Set<String> hostIds = groupsSnapshot.docs
          .map((doc) => (doc.data()['createdBy'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final Map<String, double> hostRatings = {};
      final List<String> hostIdList = hostIds.toList();

      for (int i = 0; i < hostIdList.length; i += 10) {
        final batch = hostIdList.sublist(
          i,
          i + 10 > hostIdList.length ? hostIdList.length : i + 10,
        );
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final userDoc in usersSnapshot.docs) {
          final data = userDoc.data();
          hostRatings[userDoc.id] =
              (data['average_rating'] as num?)?.toDouble() ?? 0.0;
        }
      }

      final List<Map<String, dynamic>> items = groupsSnapshot.docs.map((doc) {
        final data = doc.data();
        final String hostId = data['createdBy'] ?? '';
        final double rating = hostRatings[hostId] ?? 0.0;

        final int durationValue = (data['duration'] as num?)?.toInt() ?? 1;
        final String durationUnit = data['durationUnit'] ?? 'Months';
        final String durationStr = '$durationValue $durationUnit';

        final String serviceName = data['serviceName'] ?? '';
        String category = serviceName;
        final String serviceNameLower = serviceName.toLowerCase();
        if (serviceNameLower.contains('netflix')) {
          category = 'Netflix';
        } else if (serviceNameLower.contains('spotify')) {
          category = 'Spotify';
        } else if (serviceNameLower.contains('youtube')) {
          category = 'Youtube';
        } else if (serviceNameLower.contains('disney')) {
          category = 'Disney+';
        }

        final DateTime showInMarketAt =
            (data['showInMarketAt'] as Timestamp?)?.toDate() ??
            (data['createdAt'] as Timestamp?)?.toDate() ??
            DateTime.now();

        return {
          'id': doc.id,
          'name': serviceName,
          'host': data['creatorName'] ?? 'Unknown',
          'price': data['price']?.toString() ?? '0',
          'duration': durationStr,
          'logo': data['logo'] ?? 'assets/images/netflix.png',
          'category': category,
          'rating': double.parse(rating.toStringAsFixed(1)),
          'createdBy': hostId,
          'timestamp': showInMarketAt,
          // เก็บ members และ availableSlots เพื่อใช้ตรวจสอบตอน join
          'members': List<dynamic>.from(data['members'] ?? []),
          'availableSlots': data['availableSlots'] ?? 0,
        };
      }).toList();

      setState(() {
        _marketplaceItems = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Marketplace fetch error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------------------ //
  //  SEND JOIN REQUEST
  // ------------------------------------------------------------------ //

  Future<void> _sendJoinRequest(
    BuildContext context,
    Map<String, dynamic> item,
    String serviceEmail,
  ) async {
    // capture ก่อน async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List<dynamic> members = item['members'] ?? [];
    if (members.contains(user.uid)) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("You are already a member of this group")),
      );
      return;
    }

    if ((item['availableSlots'] ?? 0) <= 0) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("This group is full")),
      );
      return;
    }

    try {
      // ดึง username ของ current user
      String currentUserName = "Unknown";
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          currentUserName =
              userData['username'] ?? userData['email'] ?? "Unknown";
        }
      } catch (e) {
        debugPrint(e.toString());
      }

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
    } catch (e) {
      debugPrint(e.toString());
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Failed to send request")),
      );
    }
  }

  // ------------------------------------------------------------------ //
  //  MODALS
  // ------------------------------------------------------------------ //

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
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        _sendJoinRequest(this.context, item, email).catchError((
                          e,
                        ) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Failed to send request"),
                            ),
                          );
                        });
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

  // ------------------------------------------------------------------ //
  //  FILTERING & SORTING
  // ------------------------------------------------------------------ //

  List<Map<String, dynamic>> get _filteredItems {
    var items = List<Map<String, dynamic>>.from(_marketplaceItems);

    if (_selectedFilter != 0) {
      String selectedCategory = _filters[_selectedFilter];
      items = items
          .where((item) => item['category'] == selectedCategory)
          .toList();
    }

    if (_selectedDuration != "All") {
      items = items
          .where(
            (item) => item['duration'].toLowerCase().contains(
              _selectedDuration.toLowerCase(),
            ),
          )
          .toList();
    }

    if (_selectedFilter == 0) {
      items.sort((a, b) {
        DateTime timeA = a['timestamp'] as DateTime;
        DateTime timeB = b['timestamp'] as DateTime;
        return timeB.compareTo(timeA);
      });
    } else {
      switch (_selectedSort) {
        case "Rating":
          items.sort((a, b) {
            double ratingA = (a['rating'] as num?)?.toDouble() ?? 0.0;
            double ratingB = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return ratingB.compareTo(ratingA);
          });
          break;
        case "Price":
          items.sort((a, b) {
            int priceA = int.tryParse(a['price'] ?? '0') ?? 0;
            int priceB = int.tryParse(b['price'] ?? '0') ?? 0;
            return priceA.compareTo(priceB);
          });
          break;
        case "Duration":
          items.sort((a, b) {
            int durationA = _parseDuration(a['duration'] ?? '0 days');
            int durationB = _parseDuration(b['duration'] ?? '0 days');
            return durationA.compareTo(durationB);
          });
          break;
      }
    }

    return items;
  }

  int _parseDuration(String duration) {
    final parts = duration.split(' ');
    if (parts.length < 2) return 0;
    int value = int.tryParse(parts[0]) ?? 0;
    String unit = parts[1].toLowerCase();
    if (unit.contains('month')) return value * 30;
    if (unit.contains('year')) return value * 365;
    if (unit.contains('day')) return value;
    return 0;
  }

  void _resetFilters() {
    setState(() {
      _selectedSort = "Rating";
      _selectedDuration = "All";
    });
  }

  // ------------------------------------------------------------------ //
  //  BUILD
  // ------------------------------------------------------------------ //

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Marketplace",
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  )
                : _buildMarketplaceGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      children: [
        SizedBox(
          height: 40.0,
          child: _selectedFilter == 0
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 15.0),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = index;
                            if (index != 0) _resetFilters();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          decoration: BoxDecoration(
                            color: index == 0 ? Colors.black : Colors.white,
                            border: Border.all(color: Colors.black, width: 1.0),
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                          child: Center(
                            child: Text(
                              _filters[index],
                              style: TextStyle(
                                color: index == 0 ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = 0;
                            _resetFilters();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18.0),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.black, width: 1.0),
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Text(
                                  _filters[_selectedFilter],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: Row(
                          children: [
                            _buildSortButton(),
                            const SizedBox(width: 10),
                            _buildFilterButton(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSortButton() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        offset: const Offset(0, 5),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(
            color: Color.fromARGB(255, 237, 237, 237),
            width: 1,
          ),
        ),
        popUpAnimationStyle: AnimationStyle(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        ),
        onSelected: (String value) => setState(() => _selectedSort = value),
        itemBuilder: (BuildContext context) {
          return _sortOptions.map((sort) {
            return PopupMenuItem<String>(
              value: sort,
              child: Row(
                children: [
                  Text(
                    sort,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (sort == _selectedSort) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18, color: Colors.black),
                  ],
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          height: 40.0,
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 237, 237, 237),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, color: Color(0xFF5C5E62), size: 20),
              SizedBox(width: 5),
              Text(
                "Sort",
                style: TextStyle(fontSize: 14.0, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        position: PopupMenuPosition.under,
        offset: const Offset(0, 5),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(
            color: Color.fromARGB(255, 237, 237, 237),
            width: 1,
          ),
        ),
        popUpAnimationStyle: AnimationStyle(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
        ),
        onSelected: (String value) => setState(() => _selectedDuration = value),
        itemBuilder: (BuildContext context) {
          return _durationOptions.map((duration) {
            return PopupMenuItem<String>(
              value: duration,
              child: Row(
                children: [
                  Text(
                    duration,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (duration == _selectedDuration) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 18, color: Colors.black),
                  ],
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          height: 40.0,
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 237, 237, 237),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, color: Color(0xFF5C5E62), size: 20),
              SizedBox(width: 5),
              Text(
                "Duration",
                style: TextStyle(fontSize: 14.0, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceGrid() {
    final items = _filteredItems;

    if (items.isEmpty) {
      return const Center(
        child: Text(
          "No listings available",
          style: TextStyle(fontSize: 14.0, color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(15.0, 0, 15.0, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15.0,
        mainAxisSpacing: 15.0,
        childAspectRatio: 0.83,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMarketplaceCard(items[index]),
    );
  }

  Widget _buildMarketplaceCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showSubscriptionRequestModal(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: const Color.fromARGB(255, 227, 226, 226),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 63.0,
                  height: 63.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
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
              ),
              const SizedBox(height: 15),
              Text(
                item['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${item['price']} THB",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['duration'],
                style: const TextStyle(fontSize: 14.0, color: Colors.black),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFFB700)),
                  const SizedBox(width: 4),
                  Text(
                    "${item['rating']}",
                    style: const TextStyle(fontSize: 12.0, color: Colors.black),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
