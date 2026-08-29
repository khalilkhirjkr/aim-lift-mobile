// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // To navigate to MainScreen
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!mounted) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Please enter both username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Base URL is configured in lib/config.dart
    final String apiUrl = '${AppConfig.apiBaseUrl}/auth/token/';

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              'username': username,
              'password': password,
            }),
          )
          // Long timeout: the free Render backend can take ~50s to wake from idle.
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        // --- Login Successful ---
        final responseData = jsonDecode(response.body);
        final String? token = responseData['access']; // Key is 'access' for JWT

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', token);
          print('Login successful, token saved.');

          // Navigate to the main app screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ), // Navigate to MainNavigationScreen
          );
        } else {
          _showError('Login successful, but no token received.');
        }
      } else {
        // --- Login Failed ---
        String errorMessage = 'Login failed. Please check credentials.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['detail'] ?? 'Invalid username or password.';
        } catch (e) {
          // Use default message
        }
        _showError(errorMessage);
        print('Login Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Could not connect to server. Check network/IP.');
      print('Login Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size for responsive padding
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      // Use the app-wide background color
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // 1. Logo
                Image.asset(
                  'assets/images/AIMLogo.png',
                  height: screenHeight * 0.15, // 15% of screen height
                  fit: BoxFit.contain,
                ),
                SizedBox(height: screenHeight * 0.01), // Small gap
                // 2. App Name
                const Text(
                  'AIM-LIFT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                // 3. Subtitle
                Text(
                  'PREDICTIVE MAINTENANCE SYSTEM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: screenHeight * 0.05), // Larger gap
                // 4. Username Field
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16.0), // Spacing
                // 5. Password Field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  obscureText: true, // Hide password
                ),
                const SizedBox(height: 32.0), // Spacing
                // 6. Login Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor: Colors.indigo, // Match theme
                          foregroundColor: Colors.white, // Text color
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              12.0,
                            ), // Match text fields
                          ),
                        ),
                        child: const Text('LOG IN'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
