import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HostGroupDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subscription;

  const HostGroupDetailsPage({super.key, required this.subscription});

  @override
  State<HostGroupDetailsPage> createState() => _HostGroupDetailsPageState();
}

class _HostGroupDetailsPageState extends State<HostGroupDetailsPage> {
  bool _isCopied = false;
  bool _showInMarket = false;
  late String _inviteCode;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.subscription['inviteCode'] ?? _generateInviteCode();
    final data = widget.subscription;
    _showInMarket = data['showInMarket'] ?? false;
  }

  String _generateInviteCode() {
    final random = Random();
    String letters = '';
    for (int i = 0; i < 3; i++) {
      letters += String.fromCharCode(random.nextInt(26) + 65);
    }
    String numbers = '';
    for (int i = 0; i < 4; i++) {
      numbers += random.nextInt(10).toString();
    }
    return '$letters-$numbers';
  }

  void _handleCopy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _isCopied = true;
    });
    Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  Future<void> _updateMarketStatus(bool value) async {
    setState(() {
      _showInMarket = value;
    });

    final String? docId = widget.subscription['id'];
    if (docId != null) {
      try {
        await FirebaseFirestore.instance.collection('groups').doc(docId).update(
          {'showInMarket': value},
        );
      } catch (e) {
        if (mounted) setState(() => _showInMarket = !value);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final String? docId = widget.subscription['id'];
    Navigator.of(context).pop();

    if (docId != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(docId)
            .delete();

        if (mounted) {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("เกิดข้อผิดพลาด: $e")));
        }
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showDeleteConfirmationDialog() {
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
            height: 165.0,
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
                    children: [
                      const Text(
                        'Delete Subscription',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Are you sure you want to delete this subscription?',
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
                      onPressed: _deleteGroup,
                      style: TextButton.styleFrom(
                        splashFactory: NoSplash.splashFactory,
                        overlayColor: Colors.transparent,
                      ),
                      child: const Text(
                        'Delete',
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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> subscriptionData = widget.subscription;

    List<dynamic> rawMembers = subscriptionData['members'] ?? [];

    // ⭐ ดึงข้อมูล Member Names และ Status
    Map<String, dynamic> memberNames = subscriptionData['memberNames'] ?? {};
    Map<String, dynamic> memberStatus = subscriptionData['memberStatus'] ?? {};

    List<Map<String, dynamic>> displayMembers = [];

    for (var memberUid in rawMembers) {
      bool isMe = memberUid == currentUserId;
      bool isHost = memberUid == subscriptionData['createdBy'];

      // หาชื่อ
      String displayName = "Member";
      if (isHost) {
        displayName = subscriptionData['creatorName'] ?? 'Host';
      } else if (memberNames.containsKey(memberUid)) {
        displayName = memberNames[memberUid];
      }

      // หาสถานะ
      String status = "Unpaid";
      if (isHost) {
        status = "Paid";
      } else if (memberStatus.containsKey(memberUid)) {
        String s = memberStatus[memberUid];
        status = s[0].toUpperCase() + s.substring(1);
      }

      displayMembers.add({
        'name': isMe ? "$displayName (Me)" : displayName,
        'status': status,
        'isMe': isMe,
        'email': '',
      });
    }

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
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outlined, color: Colors.black),
              onPressed: _showDeleteConfirmationDialog,
            ),
          ],
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
                            subscriptionData['logo'] ??
                                'assets/images/netflix.png',
                          ),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {},
                        ),
                        color: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      subscriptionData['serviceName'] ?? 'Unknown Service',
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${subscriptionData['price']?.toString() ?? '0'} THB",
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
                  "Invite Code",
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 15.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _inviteCode,
                      style: const TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    InkWell(
                      onTap: () => _handleCopy(_inviteCode),
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
                const SizedBox(height: 20.0),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "Show in Market",
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.70,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: _showInMarket,
                        onChanged: (value) => _updateMarketStatus(value),
                        activeTrackColor: const Color.fromARGB(255, 92, 94, 98),
                        inactiveTrackColor: Colors.grey.shade400,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        trackOutlineColor: WidgetStateProperty.all(
                          Colors.transparent,
                        ),
                        thumbColor: WidgetStateProperty.all(Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24.0),

                const Text(
                  "Member",
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 15.0),
                ...displayMembers.map((member) {
                  return _buildMemberItem(
                    member['name']?.isNotEmpty == true
                        ? member['name'][0].toUpperCase()
                        : '?',
                    member['name'] ?? 'Unknown',
                    member['status'] ?? 'Unpaid',
                    member['isMe'] ?? false,
                    member['email'] ?? '',
                  );
                }),
                const SizedBox(height: 30.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberItem(
    String initial,
    String name,
    String status,
    bool isMe,
    String email,
  ) {
    Color statusBgColor;
    Color statusTextColor;

    switch (status) {
      case "Paid":
        statusBgColor = const Color.fromARGB(52, 65, 163, 19);
        statusTextColor = const Color.fromARGB(255, 65, 163, 19);
        break;
      case "Pending":
        statusBgColor = const Color.fromARGB(54, 255, 183, 0);
        statusTextColor = const Color.fromARGB(255, 255, 183, 0);
        break;
      case "Unpaid":
      default:
        statusBgColor = const Color.fromARGB(255, 255, 214, 214);
        statusTextColor = const Color.fromARGB(255, 177, 6, 15);
        break;
    }

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14.0,
                    color: Colors.black,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (!isMe && email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      email,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isMe)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Text(
                "• $status",
                style: TextStyle(
                  fontSize: 12.0,
                  color: statusTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
