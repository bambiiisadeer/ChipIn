import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HostProfilePage extends StatefulWidget {
  final String hostUserId;
  final String hostUsername;

  const HostProfilePage({
    super.key,
    required this.hostUserId,
    required this.hostUsername,
  });

  @override
  State<HostProfilePage> createState() => _HostProfilePageState();
}

class _HostProfilePageState extends State<HostProfilePage> {
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  bool _isLoadingReviews = true;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _username = widget.hostUsername;
    _loadHostUsername();
    _loadReviews();
  }

  Future<void> _loadHostUsername() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.hostUserId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _username = data?['username'] ?? widget.hostUsername;
        });
      }
    } catch (e) {
      debugPrint("Error loading host username: $e");
    }
  }

  Future<void> _loadReviews() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('hostUserId', isEqualTo: widget.hostUserId)
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
  Widget build(BuildContext context) {
    final int reviewCount = _reviews.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                  _username.isNotEmpty ? _username[0].toUpperCase() : "U",
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: Color.fromARGB(255, 92, 94, 98),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Username
            Text(
              _username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
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
                    _buildStarRow(_averageRating),
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
            // Reviews List
            Expanded(
              child: _isLoadingReviews
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : reviewCount == 0
                  ? const SizedBox.shrink()
                  : ListView.separated(
                      itemCount: reviewCount,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildReviewItem(_reviews[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
