import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

// ==========================================
// 🔴 LOCAL PROVIDER (สำหรับดึง Reviews)
// ==========================================
final userReviewsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return const Stream.empty();

      return FirebaseFirestore.instance
          .collection('reviews')
          .where('hostUserId', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
            final reviews = snapshot.docs.map((doc) => doc.data()).toList();

            reviews.sort((a, b) {
              final aTime = a['createdAt'] as Timestamp?;
              final bTime = b['createdAt'] as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            return reviews;
          });
    });

// ==========================================
// 🔵 MAIN PAGE
// ==========================================
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _isEditingUsername = false;

  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _usernameFocusNode = FocusNode();

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  // ==========================================
  // ฟังก์ชันสลับโหมดและบันทึกชื่อ (Global Update สุดยอดกวาดเรียบ!)
  // ==========================================
  void _toggleEditMode() async {
    final currentUser = ref.read(userProfileProvider).value;

    if (_isEditingUsername) {
      if (currentUser == null) {
        setState(() {
          _isEditingUsername = false;
          _usernameFocusNode.unfocus();
        });
        return;
      }

      String newName = _usernameController.text.trim();

      if (newName.isNotEmpty && newName != currentUser.username) {
        try {
          String uid = ref.read(authStateProvider).value!.uid;

          // 1. อัปเดตตาราง users
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'username': newName,
          });

          // 2. อัปเดตตาราง groups (ในฐานะ Host)
          final hostGroupsQuery = await FirebaseFirestore.instance
              .collection('groups')
              .where('createdBy', isEqualTo: uid)
              .get();
          for (final doc in hostGroupsQuery.docs) {
            await doc.reference.update({'creatorName': newName});
          }

          // 3. อัปเดตตาราง groups (ในฐานะ Member)
          final memberGroupsQuery = await FirebaseFirestore.instance
              .collection('groups')
              .where('members', arrayContains: uid)
              .get();
          for (final doc in memberGroupsQuery.docs) {
            final data = doc.data();
            if (data['createdBy'] == uid) continue;
            await doc.reference.update({'memberNames.$uid': newName});
          }

          // 4. อัปเดตตาราง reviews
          final reviewsQuery = await FirebaseFirestore.instance
              .collection('reviews')
              .where('reviewerUserId', isEqualTo: uid)
              .get();
          for (final doc in reviewsQuery.docs) {
            await doc.reference.update({
              'reviewerUsername': newName,
              'reviewerInitial': newName.isNotEmpty
                  ? newName[0].toUpperCase()
                  : 'U',
            });
          }

          // ---------------------------------------------------------
          // 5. 🔥 อัปเดตตาราง notifications (ในฐานะคนส่ง) แบบ Rebuild ประโยคใหม่ลง Database
          // ---------------------------------------------------------
          final notifSentQuery = await FirebaseFirestore.instance
              .collection('notifications')
              .where('fromUserId', isEqualTo: uid)
              .get();

          for (final doc in notifSentQuery.docs) {
            final data = doc.data();
            final String type = data['type'] ?? '';
            final String category =
                data['category'] ?? ''; // บางทีคุณใช้ category ในการแยก

            // อัปเดต Field ชื่อทั้งหมดให้เป็นปัจจุบัน
            Map<String, dynamic> updates = {'fromUserName': newName};
            if (data.containsKey('sender')) {
              updates['sender'] = newName;
            }

            // ==============================================
            // 🔨 ประกอบประโยค message ใหม่ แล้วอัปเดตลง Database เลย!
            // ==============================================

            // Case 1: คนขอเข้าร่วมกลุ่ม (อาจจะมีหรือไม่มี email ต่อท้าย)
            if (type == 'incoming_request' || category == 'incoming_request') {
              String serviceEmail = data['serviceEmail'] ?? '';
              if (serviceEmail.isNotEmpty) {
                updates['message'] =
                    "$newName want to join your group with email $serviceEmail";
              } else {
                updates['message'] = "$newName want to join your group";
              }
            }
            // Case 2: คนส่งสลิปจ่ายเงิน
            else if (type == 'payment_received' || category == 'check_slip') {
              updates['message'] = "$newName sent payment";
            }
            // Case 3: โฮสต์กดอนุมัติ
            else if (type == 'approved') {
              String serviceEmail = data['serviceEmail'] ?? '';
              if (serviceEmail.isNotEmpty) {
                updates['message'] =
                    "$newName has been approve your request with email $serviceEmail";
              } else {
                updates['message'] = "$newName has been approve your request";
              }
            }
            // Case 4: โฮสต์กดปฏิเสธ
            else if (type == 'rejected') {
              updates['message'] = "$newName has been rejected your request";
            }
            else if (type == 'payment_approved') {
              updates['message'] = "$newName has approved your payment";
            } else if (type == 'payment_rejected') {
              updates['message'] =
                  "$newName has rejected your payment. Please submit again.";
            }

            // สั่งอัปเดตลง Database ทีเดียว!
            await doc.reference.update(updates);
          }

          debugPrint("✅ Username updated globally successfully!");
        } catch (e) {
          debugPrint("❌ Failed to update username globally: $e");
          _usernameController.text = currentUser.username;
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

  // ==========================================
  // UI Components
  // ==========================================
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
    final userProfileAsync = ref.watch(userProfileProvider);
    final userReviewsAsync = ref.watch(userReviewsProvider);

    final bool isFetching = userProfileAsync.isLoading;
    final UserModel? user = userProfileAsync.value;
    final bool isLoadingReviews = userReviewsAsync.isLoading;
    final List<Map<String, dynamic>> reviews = userReviewsAsync.value ?? [];

    if (user != null && !_isEditingUsername) {
      if (_usernameController.text != user.username) {
        _usernameController.value = TextEditingValue(
          text: user.username,
          selection: TextSelection.collapsed(offset: user.username.length),
        );
      }
    }

    final int reviewCount = reviews.length;
    double averageRating = 0.0;
    if (reviewCount > 0) {
      double total = 0;
      for (var r in reviews) {
        total += (r['rating'] as num).toDouble();
      }
      averageRating = total / reviewCount;
    }

    Widget buildStarRow(double avg) {
      return Row(
        children: List.generate(5, (index) {
          if (avg >= index + 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(Icons.star, size: 24, color: Color(0xFFFFC107)),
            );
          } else if (avg > index && avg < index + 1) {
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
      body: isFetching
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 20.0),
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
                            : (user?.email.isNotEmpty == true
                                  ? user!.email[0].toUpperCase()
                                  : "U"),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 92, 94, 98),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  Text(
                    user?.email ?? "Loading...",
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          buildStarRow(averageRating),
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
                                        averageRating ==
                                            averageRating.truncateToDouble()
                                        ? averageRating.toInt().toString()
                                        : averageRating.toStringAsFixed(1),
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
                  Expanded(
                    child: isLoadingReviews
                        ? const Center(child: CircularProgressIndicator())
                        : reviewCount == 0
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            itemCount: reviewCount,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildReviewItem(reviews[index]);
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
