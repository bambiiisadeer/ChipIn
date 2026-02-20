import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class CreateNewGroupPage extends StatefulWidget {
  const CreateNewGroupPage({super.key});

  @override
  State<CreateNewGroupPage> createState() => _CreateNewGroupPageState();
}

class _CreateNewGroupPageState extends State<CreateNewGroupPage> {
  String? _selectedService;
  String? _selectedDurationUnit = "Months";
  String? _selectedBank;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  int _slotsOpen = 1;
  bool _isLoading = false;

  final List<Map<String, String>> _serviceOptions = [
    {"name": "Netflix", "image": "assets/images/netflix.png"},
    {"name": "Youtube", "image": "assets/images/youtube.png"},
    {"name": "Spotify", "image": "assets/images/spotify.png"},
    {"name": "Disney +", "image": "assets/images/disney+.png"},
  ];

  final List<String> _durationUnits = ["Days", "Months", "Years"];

  List<Map<String, String>> get _bankOptions => [
    {"name": "SCB", "image": "assets/images/scb.png"},
    {"name": "Kbank", "image": "assets/images/kbank.png"},
    {"name": "Bangkok Bank", "image": "assets/images/bangkokbank.webp"},
    {"name": "Krungsri", "image": "assets/images/krungsri.webp"},
    {"name": "True Money Wallet", "image": "assets/images/truemoney.png"},
  ];

  String _generateInviteCode() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String letters = List.generate(
      3,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
    String numbers = List.generate(4, (index) => random.nextInt(10)).join();
    return '$letters-$numbers';
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String>? selectedServiceData;
    if (_selectedService != null) {
      selectedServiceData = _serviceOptions.firstWhere(
        (element) => element['name'] == _selectedService,
      );
    }

    Map<String, String>? selectedBankData;
    if (_selectedBank != null) {
      selectedBankData = _bankOptions.firstWhere(
        (element) => element['name'] == _selectedBank,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        title: const Text(
          "Create Subscription",
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(left: 15.0, right: 15.0, top: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Service",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15.0),
              _buildServiceDropdown(selectedServiceData),
              const SizedBox(height: 25.0),
              const Text(
                "Total Price",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15.0),
              _buildPriceField(),
              const SizedBox(height: 25.0),
              const Text(
                "Duration",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15.0),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildDurationField()),
                  const SizedBox(width: 10.0),
                  Expanded(child: _buildDurationUnitDropdown()),
                ],
              ),
              const SizedBox(height: 25.0),
              const Text(
                "Payment Info",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15.0),
              Row(
                children: [
                  Expanded(flex: 2, child: _buildNameField()),
                  const SizedBox(width: 10.0),
                  Expanded(child: _buildBankDropdown(selectedBankData)),
                ],
              ),
              const SizedBox(height: 10.0),
              _buildBankAccountField(),
              const SizedBox(height: 25.0),
              const Text(
                "Slots Open (Include yourself)",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15.0),
              _buildSlotsCounter(),
              const SizedBox(height: 10.0),
              Center(
                child: Text(
                  "The group will disappear once all slots are filled",
                  style: TextStyle(fontSize: 12.0, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 20.0),
              SizedBox(
                width: double.infinity,
                height: 47.0,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_selectedService != null &&
                              _priceController.text.isNotEmpty) {
                            setState(() => _isLoading = true);

                            try {
                              final user = FirebaseAuth.instance.currentUser;

                              // ดึง username จาก Firestore แทน displayName
                              String creatorName = 'Host';
                              if (user != null) {
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .get();
                                if (userDoc.exists) {
                                  final userData =
                                      userDoc.data() as Map<String, dynamic>;
                                  creatorName =
                                      userData['username'] ??
                                      userData['email'] ??
                                      'Host';
                                }
                              }

                              // คำนวณวันหมดอายุ
                              DateTime endDate = DateTime.now();
                              int duration =
                                  int.tryParse(_durationController.text) ?? 1;
                              if (_selectedDurationUnit == "Months") {
                                endDate = DateTime(
                                  endDate.year,
                                  endDate.month + duration,
                                  endDate.day,
                                );
                              } else if (_selectedDurationUnit == "Days") {
                                endDate = endDate.add(Duration(days: duration));
                              } else {
                                endDate = DateTime(
                                  endDate.year + duration,
                                  endDate.month,
                                  endDate.day,
                                );
                              }

                              // คำนวณราคา
                              double totalPrice =
                                  double.tryParse(_priceController.text) ?? 0.0;
                              int membersCount = _slotsOpen > 0
                                  ? _slotsOpen
                                  : 1;
                              double pricePerPerson = totalPrice / membersCount;
                              double formattedPrice = double.parse(
                                pricePerPerson.toStringAsFixed(2),
                              );

                              // สร้าง Invite Code
                              String newInviteCode = _generateInviteCode();

                              // บันทึกข้อมูลลง Firestore
                              await FirebaseFirestore.instance
                                  .collection('groups')
                                  .add({
                                    'serviceName': _selectedService,
                                    'price': formattedPrice,
                                    'totalPrice': totalPrice,
                                    'duration': duration,
                                    'durationUnit': _selectedDurationUnit,
                                    'payeeName': _nameController.text,
                                    'bankName': _selectedBank,
                                    'bankAccount': _bankAccountController.text,
                                    'maxSlots': _slotsOpen,
                                    'availableSlots': _slotsOpen,
                                    'createdBy': user?.uid,
                                    'creatorName': creatorName,
                                    'memberNames': {
                                      if (user != null) user.uid: creatorName,
                                    },
                                    'members': [user?.uid],
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'endDate': endDate,
                                    'status': 'unpaid',
                                    'logo': selectedServiceData!['image'],
                                    'inviteCode': newInviteCode,
                                  });

                              if (mounted) {
                                Navigator.pop(context, true);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDropdown(Map<String, String>? selectedServiceData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: PopupMenuButton<String>(
            position: PopupMenuPosition.under,
            offset: const Offset(0, 5),
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            popUpAnimationStyle: AnimationStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            ),
            onSelected: (String value) =>
                setState(() => _selectedService = value),
            itemBuilder: (BuildContext context) {
              return _serviceOptions.map((item) {
                return PopupMenuItem<String>(
                  value: item['name'],
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(item['image']!),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          item['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 47.0,
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: const Color.fromRGBO(245, 245, 245, 1),
                border: Border.all(color: Colors.transparent, width: 1.0),
              ),
              child: Row(
                children: [
                  if (_selectedService == null)
                    const Text(
                      "Service",
                      style: TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(selectedServiceData!['image']!),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          selectedServiceData['name']!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down_outlined,
                    color: Color(0xFF5C5E62),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceField() {
    return Container(
      height: 47.0,
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: const Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 14.0),
              decoration: const InputDecoration(
                hintText: "Total Price",
                hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14.0),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const Text(
            "THB",
            style: TextStyle(color: Colors.black, fontSize: 14.0),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationField() {
    return Container(
      height: 47.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: const Color(0xFFF5F5F5),
      ),
      child: TextField(
        controller: _durationController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 14.0),
        decoration: const InputDecoration(
          hintText: "Duration",
          hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14.0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 14.0,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationUnitDropdown() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: PopupMenuButton<String>(
            position: PopupMenuPosition.under,
            offset: const Offset(0, 5),
            constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            popUpAnimationStyle: AnimationStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            ),
            onSelected: (String value) =>
                setState(() => _selectedDurationUnit = value),
            itemBuilder: (BuildContext context) {
              return _durationUnits.map((unit) {
                return PopupMenuItem<String>(
                  value: unit,
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 47.0,
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: const Color(0xFFF5F5F5),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedDurationUnit ?? "Months",
                    style: const TextStyle(color: Colors.black, fontSize: 14.0),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down_outlined,
                    color: Color(0xFF5C5E62),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNameField() {
    return Container(
      height: 47.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: const Color(0xFFF5F5F5),
      ),
      child: TextField(
        controller: _nameController,
        style: const TextStyle(fontSize: 14.0),
        decoration: const InputDecoration(
          hintText: "Name",
          hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14.0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 14.0,
          ),
        ),
      ),
    );
  }

  Widget _buildBankDropdown(Map<String, String>? selectedBankData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: PopupMenuButton<String>(
            position: PopupMenuPosition.under,
            offset: const Offset(0, 5),
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            popUpAnimationStyle: AnimationStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
            ),
            onSelected: (String value) => setState(() => _selectedBank = value),
            itemBuilder: (BuildContext context) {
              return _bankOptions.map((item) {
                return PopupMenuItem<String>(
                  value: item['name'],
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(item['image']!),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          item['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 47.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: const Color(0xFFF5F5F5),
              ),
              child: Row(
                children: [
                  if (_selectedBank == null)
                    const Expanded(
                      child: Text(
                        "Bank",
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24.0,
                            height: 24.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: AssetImage(selectedBankData!['image']!),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Text(
                              selectedBankData['name']!,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Icon(
                    Icons.keyboard_arrow_down_outlined,
                    color: Color(0xFF5C5E62),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBankAccountField() {
    return Container(
      height: 47.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: const Color(0xFFF5F5F5),
      ),
      child: TextField(
        controller: _bankAccountController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 14.0),
        decoration: const InputDecoration(
          hintText: "Bank Account Number",
          hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14.0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 14.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSlotsCounter() {
    String getPeopleImage() {
      if (_slotsOpen >= 1 && _slotsOpen <= 6) {
        return 'assets/images/${_slotsOpen}people.png';
      }
      return 'assets/images/1people.png';
    }

    return Center(
      child: Column(
        children: [
          Image.asset(getPeopleImage(), height: 38.0, fit: BoxFit.contain),
          const SizedBox(height: 15.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (_slotsOpen > 1) setState(() => _slotsOpen--);
                },
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: const Icon(Icons.remove),
                ),
              ),
              SizedBox(
                width: 140.0,
                child: Center(
                  child: Text(
                    "$_slotsOpen",
                    style: const TextStyle(
                      fontSize: 48.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_slotsOpen < 6) setState(() => _slotsOpen++);
                },
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    _nameController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }
}
