import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Auth/Login.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserAuthentication();
  }

  void _checkUserAuthentication() async {
    await Future.delayed(const Duration(seconds: 3)); // Simulate a loading time
    if (!mounted) return;

    // Always navigate to WelcomeScreen, regardless of authentication status
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900], // Dark background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 120,
              color: Colors.white, // White icon for contrast
            ),
            SizedBox(height: 30),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'CarMod AR',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // This color is masked by the gradient
                ),
              ),
            ),
            SizedBox(height: 50),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.lightBlueAccent, // Matching gradient color
              ),
              strokeWidth: 4,
              backgroundColor: Colors.blueAccent.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}