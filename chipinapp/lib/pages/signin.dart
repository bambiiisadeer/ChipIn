import 'package:flutter/material.dart';
import '../pages/signup.dart';
import '../pages/home.dart';
import '../services/auth_service.dart';

class SigninPage extends StatefulWidget {
  const SigninPage({super.key, this.fromSignup = false});

  final bool fromSignup;

  @override
  State<SigninPage> createState() => _SigninPageState();
}

class _SigninPageState extends State<SigninPage>
    with SingleTickerProviderStateMixin {
  bool _obscureText = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  // แยก loading state ของแต่ละปุ่ม
  bool _isSignInLoading = false;
  bool _isGoogleLoading = false;

  // ถ้าปุ่มใดปุ่มหนึ่งกำลัง loading อยู่ จะล็อคทุกปุ่มไม่ให้กดซ้อน
  bool get _isAnyLoading => _isSignInLoading || _isGoogleLoading;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isSignInLoading = true);

    String? result = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSignInLoading = false);

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

  Future<void> _handleGoogleSignIn() async {
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
            content: Text("Google Sign-in failed or cancelled"),
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
                    width: 40.0,
                  ),
                ),
              ),
              const SizedBox(height: 82.0),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Sign in to your account",
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 35.0),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.black,
                      ),
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
                      style: const TextStyle(
                        fontSize: 14.0,
                        color: Colors.black,
                      ),
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
                    // ปุ่ม Sign in — spinner เฉพาะปุ่มนี้เท่านั้น
                    GestureDetector(
                      onTap: _isAnyLoading ? null : _handleLogin,
                      child: Container(
                        height: 47.0,
                        decoration: BoxDecoration(
                          color: _isAnyLoading ? Colors.grey : Colors.black,
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        child: Center(
                          child: _isSignInLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Sign in",
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Center(
                      child: Text(
                        "Or  sign in with",
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
                          onTap: _isAnyLoading ? null : _handleGoogleSignIn,
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
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  spacing: 10.0,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have any account?",
                      style: TextStyle(
                        color: const Color.fromARGB(255, 92, 94, 98),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isAnyLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const SignupPage(),
                                  transitionDuration: Duration.zero,
                                  reverseTransitionDuration: Duration.zero,
                                ),
                              );
                            },
                      child: const Text(
                        "Sign up",
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
