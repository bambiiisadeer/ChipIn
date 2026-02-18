import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../pages/signin.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  late AnimationController _textFadeController;
  late Animation<double> _textFadeAnimation;
  bool _videoFinished = false;
  bool _showStatic = false;

  @override
  void initState() {
    super.initState();

    _textFadeController = AnimationController(
      duration: const Duration(milliseconds: 10),
      vsync: this,
    );
    _textFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _textFadeController, curve: Curves.easeOut),
    );

    // Initialize video player
    _videoController =
        VideoPlayerController.asset('assets/logo/logoanimation.mov')
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController.play();

              // Listen for video completion
              _videoController.addListener(() {
                if (_videoController.value.position ==
                        _videoController.value.duration &&
                    !_videoFinished) {
                  _videoFinished = true;
                  if (mounted) {
                    setState(() {
                      _showStatic = true;
                    });

                    // Wait 3 seconds after video ends, then navigate
                    Future.delayed(const Duration(seconds: 0), () {
                      if (mounted) {
                        _textFadeController.forward();

                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SigninPage(),
                            transitionDuration: const Duration(
                              milliseconds: 900,
                            ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  final fadeAnimation =
                                      Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: const Interval(
                                            0.0,
                                            1.0,
                                            curve: Curves.easeIn,
                                          ),
                                        ),
                                      );

                                  return FadeTransition(
                                    opacity: fadeAnimation,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      }
                    });
                  }
                }
              });
            }
          });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _textFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16.0,
          children: [
            Hero(
              tag: 'logo',
              flightShuttleBuilder:
                  (
                    flightContext,
                    animation,
                    direction,
                    fromContext,
                    toContext,
                  ) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final size = Tween<double>(
                          begin: 60.0,
                          end: 40.0,
                        ).evaluate(animation);

                        final color = ColorTween(
                          begin: Colors.white,
                          end: Colors.black,
                        ).evaluate(animation);

                        return ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            color ?? Colors.white,
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(
                            "assets/images/logowhite.png",
                            height: size,
                            width: size,
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    );
                  },
              child: SizedBox(
                height: 60.0,
                width: 60.0,
                child: _videoController.value.isInitialized
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 10),
                        child: _showStatic
                            ? Image.asset(
                                "assets/logo/logowhitev2.png",
                                height: 60.0,
                                width: 60.0,
                                key: const ValueKey('static'),
                              )
                            : VideoPlayer(_videoController),
                      )
                    : const SizedBox(),
              ),
            ),
            FadeTransition(
              opacity: _textFadeAnimation,
              child: const Text(
                "ChipIn",
                style: TextStyle(
                  fontSize: 40.0,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
