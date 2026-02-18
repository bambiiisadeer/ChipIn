import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditingUsername = false;

  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();

  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _isFetching = true;

  // Reviews
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _usernameController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      String uid = currentUser.uid;
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _usernameController.text = data['username'] ?? 'User';
          _user = UserModel(
            id: data['uid'] ?? uid,
            username: data['username'] ?? 'User',
            email: data['email'] ?? '',
            authProvider: data['auth_provider'] ?? 'email',
            averageRating: (data['average_rating'] ?? 0.0).toDouble(),
            createdAt: data['created_at'] != null
                ? (data['created_at'] as Timestamp).toDate()
                : DateTime.now(),
          );
          _isFetching = false;
        });

        await _loadReviews(uid);
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() {
          _isFetching = false;
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> _loadReviews(String hostUserId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('hostUserId', isEqualTo: hostUserId)
          .get();

      final reviews = querySnapshot.docs.map((doc) => doc.data()).toList();

      reviews.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      double total = 0;
      for (var r in reviews) {
        total += (r['rating'] as num).toDouble();
      }
      final avg = reviews.isEmpty ? 0.0 : total / reviews.length;

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _averageRating = avg;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading reviews: $e");
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _toggleEditMode() async {
    if (_isEditingUsername) {
      if (_user == null) {
        setState(() {
          _isEditingUsername = false;
          _usernameFocusNode.unfocus();
        });
        return;
      }

      String newName = _usernameController.text.trim();

      if (newName.isNotEmpty && newName != _user?.username) {
        try {
          String uid = FirebaseAuth.instance.currentUser!.uid;
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'username': newName,
          });

          setState(() {
            _user = UserModel(
              id: _user!.id,
              username: newName,
              email: _user!.email,
              authProvider: _user!.authProvider,
              averageRating: _user!.averageRating,
              createdAt: _user!.createdAt,
            );
          });

          debugPrint("Username updated successfully!");
        } catch (e) {
          debugPrint("Failed to update username: $e");
          _usernameController.text = _user?.username ?? "";
        }
      }

      setState(() {
        _isEditingUsername = false;
        _usernameFocusNode.unfocus();
      });
    } else {
      setState(() {
        _isEditingUsername = true;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        _usernameFocusNode.requestFocus();
      });
    }
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final String initial = review['reviewerInitial'] ?? '?';
    final String username = review['reviewerUsername'] ?? 'Member';
    final int rating = (review['rating'] as num?)?.toInt() ?? 0;
    final String comment = review['comment'] ?? '';
    String date = '';

    if (review['createdAt'] != null) {
      final dt = (review['createdAt'] as Timestamp).toDate();
      final List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      date = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color.fromARGB(255, 227, 227, 227),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 37.0,
                height: 37.0,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 237, 237, 237),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 18.0,
                      color: Color.fromARGB(255, 92, 94, 98),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username),
                  Text(date, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                Icons.star,
                size: 20,
                color: index < rating
                    ? const Color(0xFFFFC107)
                    : const Color(0xFFD9D9D9),
              );
            }),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int reviewCount = _reviews.length;

    Widget buildStarRow(double avg) {
      return Row(
        children: List.generate(5, (index) {
          if (avg >= index + 1) {
            // ดาวเต็ม
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(Icons.star, size: 24, color: Color(0xFFFFC107)),
            );
          } else if (avg > index && avg < index + 1) {
            // ครึ่งดาว — ShaderMask คลิปครึ่งซ้ายสีเหลือง ครึ่งขวา transparent
            // เห็นดาวเทาข้างล่างแทน ไม่มีขอบเกิน
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Stack(
                children: [
                  const Icon(Icons.star, size: 24, color: Color(0xFFD9D9D9)),
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        stops: [0.5, 0.5],
                        colors: [Color(0xFFFFC107), Colors.transparent],
                      ).createShader(bounds);
                    },
                    child: const Icon(
                      Icons.star,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          } else {
            // ดาวว่าง
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(Icons.star, size: 24, color: Color(0xFFD9D9D9)),
            );
          }
        }),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: _isFetching
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20.0),
                  // Profile Picture
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 237, 237, 237),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _usernameController.text.isNotEmpty
                            ? _usernameController.text[0].toUpperCase()
                            : "U",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 92, 94, 98),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Username with edit/save icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _isEditingUsername
                          ? IntrinsicWidth(
                              child: TextField(
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                                onSubmitted: (value) => _toggleEditMode(),
                              ),
                            )
                          : Text(
                              _usernameController.text,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggleEditMode,
                        child: Icon(
                          _isEditingUsername ? Icons.check : Icons.edit,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Email
                  Text(
                    _user?.email ?? "Loading...",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  // Rating Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          buildStarRow(_averageRating),
                          const SizedBox(width: 10),
                          Text(
                            "($reviewCount)",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      reviewCount == 0
                          ? const Text(
                              "no reviews",
                              style: TextStyle(
                                fontSize: 14,
                                color: Color.fromARGB(255, 92, 94, 98),
                              ),
                            )
                          : RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        _averageRating ==
                                            _averageRating.truncateToDouble()
                                        ? _averageRating.toInt().toString()
                                        : _averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: " / 5",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Reviews Section
                  Expanded(
                    child: _isLoadingReviews
                        ? const Center(child: CircularProgressIndicator())
                        : reviewCount == 0
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            itemCount: reviewCount,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildReviewItem(_reviews[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            height: 153.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 20.0,
                    right: 20.0,
                    top: 20.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Are you sure you want to logout?',
                        style: TextStyle(fontSize: 14.0),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        await _authService.logout();
                        if (mounted) {
                          navigator.pushNamedAndRemoveUntil(
                            '/signin',
                            (route) => false,
                          );
                        }
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
