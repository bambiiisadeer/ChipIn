import 'package:flutter/material.dart';
import '../pages/home.dart';
import '../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  bool _obscureText = true;

  // แยก loading state ของแต่ละปุ่ม
  bool _isSignUpLoading = false;
  bool _isGoogleLoading = false;

  // ถ้าปุ่มใดปุ่มหนึ่งกำลัง loading อยู่ จะล็อคทุกปุ่มไม่ให้กดซ้อน
  bool get _isAnyLoading => _isSignUpLoading || _isGoogleLoading;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isSignUpLoading = true);

    String? result = await _authService.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      username: _usernameController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSignUpLoading = false);

      if (result == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);

    final result = await _authService.signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);

      if (result != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google Sign-up failed or cancelled"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.only(
          left: 15.0,
          right: 15.0,
          top: 104.0,
          bottom: 48.0,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Hero(
                  tag: 'logo',
                  child: Image.asset(
                    "assets/images/logoblack.png",
                    height: 40.0,
                  ),
                ),
              ),
              const SizedBox(height: 82.0),
              const Text(
                "Create your account",
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 35.0),
              TextField(
                controller: _usernameController,
                style: const TextStyle(fontSize: 14.0, color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Username",
                  hintStyle: const TextStyle(
                    fontSize: 14.0,
                    color: Color.fromARGB(255, 92, 94, 98),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 242, 242, 242),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(15.0),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _emailController,
                style: const TextStyle(fontSize: 14.0, color: Colors.black),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: const TextStyle(
                    fontSize: 14.0,
                    color: Color.fromARGB(255, 92, 94, 98),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 242, 242, 242),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(15.0),
                ),
              ),
              const SizedBox(height: 20.0),
              TextField(
                controller: _passwordController,
                style: const TextStyle(fontSize: 14.0, color: Colors.black),
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: const TextStyle(
                    fontSize: 14.0,
                    color: Color.fromARGB(255, 92, 94, 98),
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 242, 242, 242),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(15.0),
                  suffixIcon: IconButton(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color.fromARGB(255, 92, 94, 98),
                      size: 24.0,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 35.0),
              // ปุ่ม Sign up — spinner เฉพาะปุ่มนี้เท่านั้น
              GestureDetector(
                onTap: _isAnyLoading ? null : _handleSignUp,
                child: Container(
                  height: 47.0,
                  decoration: BoxDecoration(
                    color: _isAnyLoading ? Colors.grey : Colors.black,
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                  child: Center(
                    child: _isSignUpLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Sign up",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  "Or  sign up with",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 92, 94, 98),
                  ),
                ),
              ),
              const SizedBox(height: 17.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 30.0,
                children: [
                  // ปุ่ม Google — spinner เฉพาะปุ่มนี้เท่านั้น
                  GestureDetector(
                    onTap: _isAnyLoading ? null : _handleGoogleSignUp,
                    child: Container(
                      height: 46.0,
                      width: 46.0,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(width: 1.0),
                      ),
                      child: _isGoogleLoading
                          ? const Padding(
                              padding: EdgeInsets.all(10.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Image.asset(
                              "assets/images/googlelogo.png",
                              height: 24.0,
                            ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                spacing: 10.0,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isAnyLoading ? null : () => Navigator.pop(context),
                    child: const Text(
                      "Sign in",
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                  const Text(
                    "into existing account",
                    style: TextStyle(color: Color.fromARGB(255, 92, 94, 98)),
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
