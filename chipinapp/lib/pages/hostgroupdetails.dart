import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ Import Riverpod
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart'; // ✅ ดึง Provider มาใช้งาน

class HostGroupDetailsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> subscription;

  const HostGroupDetailsPage({super.key, required this.subscription});

  @override
  ConsumerState<HostGroupDetailsPage> createState() =>
      _HostGroupDetailsPageState();
}

class _HostGroupDetailsPageState extends ConsumerState<HostGroupDetailsPage> {
  bool _isCopied = false;
  bool _showInMarket = false;
  late String _inviteCode;

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.subscription['inviteCode'] ?? _generateInviteCode();
    _showInMarket = widget.subscription['showInMarket'] ?? false;
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
    setState(() => _isCopied = true);
    Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _updateMarketStatus(bool value) async {
    setState(() => _showInMarket = value);
    final String? docId = widget.subscription['id'];
    if (docId != null) {
      try {
        final Map<String, dynamic> updateData = {
          'showInMarket': value,
          if (value) 'showInMarketAt': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(docId)
            .update(updateData);
      } catch (e) {
        if (mounted) setState(() => _showInMarket = !value);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final String? docId = widget.subscription['id'];
    Navigator.of(context).pop(); // ปิด Dialog ยืนยัน

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
          Navigator.of(context).pop(); // ปิด loading
          Navigator.of(context).pop(); // ออกจากหน้ารายละเอียดกลุ่ม
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
                    children: const [
                      Text(
                        'Delete Subscription',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
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
    final String groupId = widget.subscription['id'] ?? '';
    // ✅ ดึง ID ของตัวเองจาก Riverpod Provider
    final String currentUserId = ref.watch(authStateProvider).value?.uid ?? "";

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

        final List<dynamic> rawMembers = sub['members'] ?? [];
        final Map<String, dynamic> memberNames = sub['memberNames'] ?? {};
        final Map<String, dynamic> memberStatus = sub['memberStatus'] ?? {};
        final Map<String, dynamic> memberEmails = sub['memberEmails'] ?? {};
        final String serviceEmail = sub['serviceEmail'] ?? '';

        List<Map<String, dynamic>> displayMembers = [];

        for (var memberUid in rawMembers) {
          bool isMe = memberUid == currentUserId;
          bool isHost = memberUid == sub['createdBy'];

          String displayName = "Member";
          if (isHost) {
            displayName =
                (sub['creatorName'] != null &&
                    sub['creatorName'].toString().isNotEmpty)
                ? sub['creatorName']
                : (memberNames[memberUid] ?? 'Host');
          } else if (memberNames.containsKey(memberUid)) {
            displayName = memberNames[memberUid];
          }

          String status = "Unpaid";
          if (isHost) {
            status = "Paid";
          } else if (memberStatus.containsKey(memberUid)) {
            String s = memberStatus[memberUid];
            status = s[0].toUpperCase() + s.substring(1);
          }

          String email = '';
          if (!isMe) {
            if (isHost) {
              email = serviceEmail;
            } else {
              email = memberEmails[memberUid] ?? '';
            }
          }

          displayMembers.add({
            'name': isMe ? "$displayName (Me)" : displayName,
            'status': status,
            'isMe': isMe,
            'email': email,
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
                                sub['logo'] ?? 'assets/images/netflix.png',
                              ),
                              fit: BoxFit.cover,
                              onError: (exception, stackTrace) {},
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
                        const SizedBox(width: 6.0),
                        _FixedThumbSwitch(
                          value: _showInMarket,
                          onChanged: _updateMarketStatus,
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
      },
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
        statusBgColor = const Color.fromARGB(255, 255, 214, 214);
        statusTextColor = const Color.fromARGB(255, 177, 6, 15);
        break;
      default:
        statusBgColor = const Color(0xFFDBEEFF);
        statusTextColor = const Color(0xFF1A7FD4);
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
                horizontal: 10.0,
                vertical: 2.0,
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

class _FixedThumbSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FixedThumbSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const trackWidth = 35.0;
    const trackHeight = 20.0;
    const thumbRadius = 7.0;
    const thumbDiameter = thumbRadius * 2;
    const padding = (trackHeight - thumbDiameter) / 2;

    final trackColor = value
        ? const Color.fromARGB(255, 92, 94, 98)
        : Colors.grey.shade400;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: trackWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(trackHeight / 2),
          color: trackColor,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Container(
              width: thumbDiameter,
              height: thumbDiameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
