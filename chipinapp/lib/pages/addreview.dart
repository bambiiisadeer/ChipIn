import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Import Riverpod
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart'; // ✅ ดึง Provider มาใช้งาน

class AddReviewPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subscription;

  const AddReviewPage({super.key, required this.subscription});

  @override
  ConsumerState<AddReviewPage> createState() => _AddReviewPageState();
}

class _AddReviewPageState extends ConsumerState<AddReviewPage> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();

  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.black,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ 1. ดึงข้อมูล User จาก Provider ได้เลย ไม่ต้อง Query ใหม่
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final userProfile = ref.read(userProfileProvider).value;
      final String currentUsername = userProfile?.username ?? 'Member';
      final String currentUserInitial = currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : 'M';

      final String hostUserId = (widget.subscription['createdBy'] as String?) ?? '';

      debugPrint('[AddReview] hostUserId="$hostUserId"');
      debugPrint('[AddReview] groupId="${widget.subscription['id']}"');

      if (hostUserId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot identify host. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final firestore = FirebaseFirestore.instance;
      final reviewsCol = firestore.collection('reviews');
      final userDocRef = firestore.collection('users').doc(hostUserId);

      // ---- Step 1: Add review doc ----
      await reviewsCol.add({
        'hostUserId': hostUserId,
        'reviewerUserId': user.uid,
        'reviewerUsername': currentUsername, // ✅ ใช้ชื่อปัจจุบัน
        'reviewerInitial': currentUserInitial, // ✅ ใช้ Initial ปัจจุบัน
        'rating': _rating,
        'comment': _reviewController.text.trim(),
        'groupId': widget.subscription['id'] ?? '',
        'serviceName': widget.subscription['serviceName'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[AddReview] Review doc added');

      // ---- Step 2: Small delay for Firestore index ----
      await Future.delayed(const Duration(milliseconds: 800));

      // ---- Step 3: Query all reviews for host & calculate average ----
      final snapshot = await reviewsCol
          .where('hostUserId', isEqualTo: hostUserId)
          .get();

      debugPrint('[AddReview] Total reviews found: ${snapshot.docs.length}');

      double total = 0;
      for (final doc in snapshot.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }

      final int count = snapshot.docs.length;
      final double average = count > 0 ? total / count : 0.0;

      debugPrint('[AddReview] average=$average count=$count');

      // ---- Step 4: Update average_rating in users doc ----
      await userDocRef.set({
        'average_rating': double.parse(average.toStringAsFixed(2)),
        'review_count': count,
      }, SetOptions(merge: true));

      // ---- Step 5: Verify the update ----
      final verifyDoc = await userDocRef.get();
      final verifyData = verifyDoc.data();
      debugPrint(
        '[AddReview] ✅ Verified average_rating=${verifyData?['average_rating']} count=${verifyData?['review_count']}',
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[AddReview] ❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 2. อ่านข้อมูลเพื่อเอามาแสดงผลบนหน้าจอผ่าน Provider
    final userProfileAsync = ref.watch(userProfileProvider);
    final isLoadingUser = userProfileAsync.isLoading;
    final String currentUsername = userProfileAsync.value?.username ?? 'Member';
    final String currentUserInitial = currentUsername.isNotEmpty ? currentUsername[0].toUpperCase() : 'M';

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
          ),
          title: Text(
            widget.subscription['serviceName'] ?? 'Review',
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10.0),
                
                // ✅ 3. ถ้ากำลังดึงข้อมูล Provider โชว์วงกลมโหลดก่อน ถ้าได้แล้วก็วาดโปรไฟล์เลย
                isLoadingUser
                    ? const SizedBox(
                        height: 37,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 37.0,
                            height: 37.0,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              currentUserInitial,
                              style: TextStyle(
                                fontSize: 18.0,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUsername,
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              const Text(
                                "This post will be shared publicly on the host's profile",
                                style: TextStyle(
                                  fontSize: 11.3,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                const SizedBox(height: 30.0),

                // Star rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          size: 30.0,
                          color: index < _rating
                              ? Colors.amber
                              : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 30.0),

                // Comment field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TextField(
                    controller: _reviewController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: 'Tell the experience you received',
                      hintStyle: TextStyle(
                        fontSize: 12.0,
                        color: Color(0xFF9E9E9E),
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16.0),
                    ),
                    style: const TextStyle(fontSize: 14.0, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 30.0),

                // Post button
                SizedBox(
                  height: 47.0,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || isLoadingUser)
                        ? null
                        : _submitReview,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.black),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      elevation: WidgetStateProperty.all(0),
                      overlayColor: WidgetStateProperty.all(Colors.transparent),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Post",
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}