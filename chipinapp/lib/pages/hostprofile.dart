import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Import Riverpod

// ==========================================
// 🔴 LOCAL PROVIDERS
// ==========================================

// 1. ดึงข้อมูล User ของ Host
final hostProfileProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>?, String>((ref, hostUserId) async {
      if (hostUserId.isEmpty) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(hostUserId)
          .get();
      return doc.exists ? doc.data() : null;
    });

// 2. ดึงรีวิวของ Host
final hostReviewsProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, hostUserId) async {
      if (hostUserId.isEmpty) return [];
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

      return reviews;
    });

// ==========================================
// 🔵 MAIN PAGE
// ==========================================

class HostProfilePage extends ConsumerWidget {
  // ✅ เปลี่ยนเป็น ConsumerWidget
  final String hostUserId;
  final String hostUsername;

  const HostProfilePage({
    super.key,
    required this.hostUserId,
    required this.hostUsername,
  });

  Widget _buildStarRow(double avg) {
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
                  child: const Icon(Icons.star, size: 24, color: Colors.white),
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

  Widget _buildReviewItem(Map<String, dynamic> review) {
    final String initial = review['reviewerInitial'] ?? '?';
    final String username = review['reviewerUsername'] ?? 'Member';
    final int rating = (review['rating'] as num?)?.toInt() ?? 0;
    final String comment = review['comment'] ?? '';
    String date = '';

    if (review['createdAt'] != null) {
      final dt = (review['createdAt'] as Timestamp).toDate();
      const months = [
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
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ เพิ่ม ref

    // ดึงข้อมูลจาก Provider
    final hostProfileAsync = ref.watch(hostProfileProvider(hostUserId));
    final reviewsAsync = ref.watch(hostReviewsProvider(hostUserId));

    // ประมวลผลชื่อและเรตติ้ง
    final String displayUsername =
        hostProfileAsync.value?['username'] ?? hostUsername;
    final List<Map<String, dynamic>> reviews = reviewsAsync.value ?? [];

    final int reviewCount = reviews.length;
    double averageRating = 0.0;

    if (reviewCount > 0) {
      double total = 0;
      for (var r in reviews) {
        total += (r['rating'] as num).toDouble();
      }
      averageRating = total / reviewCount;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 6.0),
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
                  displayUsername.isNotEmpty
                      ? displayUsername[0].toUpperCase()
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
            // Username (Show loading state slightly if loading)
            hostProfileAsync.when(
              loading: () => const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) => Text(
                "Error: $err",
                style: const TextStyle(color: Colors.red),
              ),
              data: (_) => Text(
                displayUsername,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 30),
            // Rating Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _buildStarRow(averageRating),
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
            // Reviews List
            Expanded(
              child: reviewsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
                error: (err, stack) =>
                    Center(child: Text("Error loading reviews: $err")),
                data: (reviewsData) {
                  if (reviewsData.isEmpty) return const SizedBox.shrink();

                  return ListView.separated(
                    itemCount: reviewsData.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildReviewItem(reviewsData[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
