import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'addreview.dart';

class GroupDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subscription;

  const GroupDetailsPage({super.key, required this.subscription});

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  bool _isCopied = false;
  File? _slipImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  String _getBankImage(String? bankName) {
    switch (bankName) {
      case 'SCB':
        return 'assets/images/scb.png';
      case 'Kbank':
        return 'assets/images/kbank.png';
      case 'Bangkok Bank':
        return 'assets/images/bangkokbank.webp';
      case 'Krungsri':
        return 'assets/images/krungsri.webp';
      case 'True Money Wallet':
        return 'assets/images/truemoney.png';
      default:
        return 'assets/images/kbank.png';
    }
  }

  void _handleCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _isCopied = true);
    Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 1024,
    );
    if (image != null) setState(() => _slipImage = File(image.path));
  }

  void _removeImage() {
    setState(() => _slipImage = null);
  }

  Future<void> _submitPayment(Map<String, dynamic> sub) async {
    if (_slipImage == null) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      final List<int> imageBytes = await _slipImage!.readAsBytes();
      final String base64Slip = base64Encode(imageBytes);

      String senderName = 'Member';
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      if (userDoc.exists) {
        senderName = userDoc['username'] ?? user?.displayName ?? 'Member';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'type': 'payment_received',
        'category': 'check_slip',
        'toUserId': sub['createdBy'],
        'fromUserId': currentUserId,
        'sender': senderName,
        'service': sub['serviceName'],
        'logo': sub['logo'],
        'groupId': sub['id'],
        'price': "${sub['price']} THB",
        'message': "$senderName sent payment",
        'timestamp': FieldValue.serverTimestamp(),
        'slipBase64': base64Slip,
        'isRead': false,
      });

      // อัปเดต memberStatus เป็น 'checking'
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(sub['id'])
          .update({'memberStatus.$currentUserId': 'checking'});

      if (mounted) {
        setState(() => _slipImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Payment submitted, waiting for host to verify.",
              style: TextStyle(
                color: Colors.white, // สีตัวหนังสือ (เช่น สีขาว)
                // ความหนาตัวหนังสือ
              ),
            ),
            backgroundColor: const Color.fromARGB(255, 30, 30, 30),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error submitting payment: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _navigateToAddReview(Map<String, dynamic> sub) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddReviewPage(subscription: sub)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String groupId = widget.subscription['id'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> sub = Map<String, dynamic>.from(
          widget.subscription,
        );

        if (snapshot.hasData && snapshot.data!.exists) {
          final liveData = snapshot.data!.data() as Map<String, dynamic>;
          sub = {...liveData, 'id': groupId};
        }

        final Map<String, dynamic> memberStatus = sub['memberStatus'] ?? {};
        final String myStatus = memberStatus[currentUserId] ?? 'unpaid';
        final bool isPaid = myStatus.toLowerCase() == 'paid';
        final bool isChecking = myStatus.toLowerCase() == 'checking';

        final List<dynamic> rawMembers = sub['members'] ?? [];
        final Map<String, dynamic> memberNames = sub['memberNames'] ?? {};

        final String payeeName = sub['payeeName'] ?? 'Unknown';
        final String bankName = sub['bankName'] ?? 'Unknown Bank';
        final String accountNumber = sub['bankAccount'] ?? '-';
        final String bankImage = _getBankImage(bankName);

        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ButtonStyle(
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                elevation: WidgetStateProperty.all(0),
              ),
            ),
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
              ),
              title: const Text(
                "Subscription Detail",
                style: TextStyle(
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
                    Row(
                      children: [
                        Container(
                          width: 37.0,
                          height: 37.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(
                                sub['logo'] ?? 'assets/images/netflix.png',
                              ),
                              fit: BoxFit.cover,
                            ),
                            color: Colors.grey.shade200,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          sub['serviceName'] ?? 'Unknown Service',
                          style: const TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "${sub['price']?.toString() ?? '0'} THB",
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24.0),

                    const Text(
                      "Members",
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15.0),

                    ...rawMembers.map((memberUid) {
                      bool isHost = memberUid == sub['createdBy'];
                      bool isMe = memberUid == currentUserId;

                      String displayName = "Member";
                      if (isHost) {
                        displayName = sub['creatorName'] ?? "Host";
                      } else if (memberNames.containsKey(memberUid)) {
                        displayName = memberNames[memberUid];
                      }

                      if (isMe) displayName = "$displayName (Me)";

                      String initial = displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?';
                      return _buildMemberItem(initial, displayName);
                    }),

                    const SizedBox(height: 8.0),
                    Center(
                      child: SizedBox(
                        height: 47,
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToAddReview(sub),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.black,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                            shape: WidgetStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24.0),
                              ),
                            ),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(horizontal: 20.0),
                            ),
                          ),
                          icon: const Icon(
                            Icons.mode_edit_outline_rounded,
                            size: 18,
                          ),
                          label: const Text("Add review"),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32.0),

                    const Text(
                      "Payment Info",
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          height: 37.0,
                          width: 37.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(bankImage),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                        ),
                        const SizedBox(width: 15.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payeeName,
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                bankName,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                accountNumber,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (accountNumber != '-')
                              _handleCopy(accountNumber);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isCopied ? Icons.check : Icons.copy,
                              size: 18.0,
                              color: const Color.fromARGB(255, 92, 94, 98),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32.0),

                    // ซ่อน Upload Slip เมื่อ status เป็น 'paid' หรือ 'checking'
                    if (!isPaid && !isChecking) ...[
                      const Text(
                        "Upload Slip",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 15.0),
                      _slipImage == null
                          ? SizedBox(
                              width: double.infinity,
                              height: 47.0,
                              child: OutlinedButton.icon(
                                onPressed: _pickImage,
                                style: ButtonStyle(
                                  foregroundColor: WidgetStateProperty.all(
                                    Colors.black,
                                  ),
                                  side: WidgetStateProperty.all(
                                    const BorderSide(color: Colors.black),
                                  ),
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.upload),
                                label: const Text("Upload Slip"),
                              ),
                            )
                          : Center(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.file(
                                      _slipImage!,
                                      width: double.infinity,
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                  Positioned(
                                    top: 5,
                                    right: 5,
                                    child: InkWell(
                                      onTap: _removeImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(4.0),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 40.0),
                      SizedBox(
                        height: 47.0,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitPayment(sub),
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.black,
                            ),
                            foregroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
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
                                  "Submit Payment",
                                  style: TextStyle(fontSize: 14.0),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberItem(String initial, String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
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
              initial,
              style: const TextStyle(
                fontSize: 18.0,
                color: Color.fromARGB(255, 92, 94, 98),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16.0),
          Text(
            name,
            style: const TextStyle(fontSize: 14.0, color: Colors.black),
          ),
        ],
      ),
    );
  }
}
