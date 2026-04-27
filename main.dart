import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SafeCircleApp());
}

class SafeCircleApp extends StatelessWidget {
  const SafeCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeCircle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F6FF),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.hasData ? const MainMapScreen() : const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter email and password');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage('Login error: ${e.code}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Enter email and password');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'name': email.split('@').first,
          'circleIds': [],
          'activeCircleId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _showMessage('Account created successfully');
    } on FirebaseAuthException catch (e) {
      _showMessage('Signup error: ${e.code}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  void _continueAsGuest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MainMapScreen(isGuest: true)),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A5AE0), Color(0xFF8B7CF6), Color(0xFFF3F1FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 18),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset('assets/images/logo1.png', height: 120),

                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFFE9E4FF),
                      child: Icon(
                        Icons.shield_outlined,
                        size: 34,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Welcome to SafeCircle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to view your circle and live locations',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration:
                          _inputDecoration(
                            'Password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openForgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _continueAsGuest,
                        child: const Text('Continue as Guest'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: _isLoading ? null : _signUp,
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Enter your email address');
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _showMessage('Password reset email sent. Check your inbox.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showMessage('Reset error: ${e.code}');
    } catch (e) {
      _showMessage('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F1FF), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 18),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFFE9E4FF),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 36,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Reset your password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your account email and SafeCircle will send you a password reset link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendResetEmail(),
                      decoration: _inputDecoration(
                        'Email address',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendResetEmail,
                        icon: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending ? 'Sending...' : 'Send Reset Email',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSending
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Back to login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleInfo {
  final String id;
  final String name;
  const CircleInfo({required this.id, required this.name});
}

class CircleMember {
  final String uid;
  final String name;
  final String email;
  final LatLng location;
  const CircleMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.location,
  });
}

class MainMapScreen extends StatefulWidget {
  final bool isGuest;
  const MainMapScreen({super.key, this.isGuest = false});
  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng _currentLocation = const LatLng(51.5074, -0.1278);
  LatLng? _searchedLocation;

  String? _meetupId;
  LatLng? _meetupLocation;
  String? _meetupName;
  bool _meetupHasAgreed = false;
  bool _meetupHasDisagreed = false;
  int _meetupAgreedCount = 0;
  int _meetupDisagreedCount = 0;
  List<LatLng> _routePoints = [];
  bool _isSatellite = false;
  bool _isSearching = false;

  String _statusText = 'Map ready';
  double _locationAccuracy = 0;
  double _currentZoom = 16.0;
  String? _searchedPlaceName;

  String? _activeCircleId;
  String? _activeCircleName;
  List<CircleInfo> _myCircles = [];

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocSubscription;

  void _showMeetupDetails({
    required String meetupId,
    required String name,
    required LatLng location,
    required bool hasAgreed,
    required bool hasDisagreed,
    required int agreedCount,
    required int disagreedCount,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EEFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Meetup point for this circle',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statusChip(
                    Icons.check_circle_rounded,
                    'Agreed $agreedCount',
                    Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _statusChip(
                    Icons.cancel_rounded,
                    'Disagreed $disagreedCount',
                    Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: Icon(Icons.directions_rounded, color: Colors.white),
                ),
                title: const Text('Get Directions'),
                subtitle: const Text('Draw route from your location'),
                onTap: () {
                  Navigator.pop(context);
                  _getRouteToMeetup(location);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: hasAgreed ? Colors.grey : Colors.green,
                  child: Icon(
                    hasAgreed ? Icons.done_all_rounded : Icons.check_rounded,
                    color: Colors.white,
                  ),
                ),
                title: Text(hasAgreed ? 'You agreed' : 'Agree to meetup'),
                subtitle: const Text(
                  'Tell your circle you accept this meetup point',
                ),
                enabled: !hasAgreed,
                onTap: hasAgreed
                    ? null
                    : () {
                        Navigator.pop(context);
                        _agreeMeetup(meetupId);
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: hasDisagreed
                      ? Colors.grey
                      : Colors.redAccent,
                  child: Icon(
                    hasDisagreed ? Icons.block_rounded : Icons.close_rounded,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  hasDisagreed ? 'You disagreed' : 'Disagree with meetup',
                ),
                subtitle: const Text(
                  'Tell your circle this meetup point does not work',
                ),
                enabled: !hasDisagreed,
                onTap: hasDisagreed
                    ? null
                    : () {
                        Navigator.pop(context);
                        _disagreeMeetup(meetupId);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _listenToUserCircles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeLocation());
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _userDocSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _listenToUserCircles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.isGuest) return;

    await _userDocSubscription?.cancel();

    _userDocSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((userDoc) async {
          if (!mounted || !userDoc.exists) return;

          final data = userDoc.data() ?? {};
          final circleIds = List<String>.from(data['circleIds'] ?? []);
          String? activeCircleId = data['activeCircleId'] as String?;

          final circles = <CircleInfo>[];

          for (final id in circleIds) {
            final circleDoc = await FirebaseFirestore.instance
                .collection('circles')
                .doc(id)
                .get();

            if (circleDoc.exists) {
              circles.add(
                CircleInfo(
                  id: id,
                  name: circleDoc.data()?['name'] ?? 'Unnamed Circle',
                ),
              );
            }
          }

          CircleInfo? activeCircle;

          if (activeCircleId != null) {
            for (final circle in circles) {
              if (circle.id == activeCircleId) {
                activeCircle = circle;
                break;
              }
            }
          }

          if (activeCircle == null && circles.isNotEmpty) {
            activeCircle = circles.first;
            activeCircleId = activeCircle.id;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'activeCircleId': activeCircle.id,
                }, SetOptions(merge: true));
          }

          if (!mounted) return;

          setState(() {
            _myCircles = circles;
            _activeCircleId = activeCircle?.id;
            _activeCircleName = activeCircle?.name;
          });
        });
  }

  Future<void> _switchCircle(CircleInfo circle) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'activeCircleId': circle.id,
    });
    setState(() {
      _activeCircleId = circle.id;
      _activeCircleName = circle.name;
      _routePoints.clear();
      _meetupId = null;
      _meetupLocation = null;
      _meetupName = null;
      _meetupHasAgreed = false;
      _meetupHasDisagreed = false;
      _meetupAgreedCount = 0;
      _meetupDisagreedCount = 0;
    });
    _showMessage('Switched to ${circle.name}');
  }

  Future<void> _confirmLeaveActiveCircle() async {
    if (_activeCircleId == null || _activeCircleName == null) {
      _showMessage('No active circle selected');
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave Circle'),
        content: Text('Do you want to leave ${_activeCircleName!}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _leaveActiveCircle();
    }
  }

  Future<void> _leaveActiveCircle() async {
    final user = FirebaseAuth.instance.currentUser;
    final circleId = _activeCircleId;
    if (user == null || circleId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('circles')
          .doc(circleId)
          .update({
            'members': FieldValue.arrayRemove([user.uid]),
          });

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userRef.get();
      final currentCircleIds = List<String>.from(
        userDoc.data()?['circleIds'] ?? [],
      );
      final remainingCircleIds = currentCircleIds
          .where((id) => id != circleId)
          .toList();
      final newActiveCircleId = remainingCircleIds.isNotEmpty
          ? remainingCircleIds.first
          : null;

      await userRef.set({
        'circleIds': FieldValue.arrayRemove([circleId]),
        'activeCircleId': newActiveCircleId,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _activeCircleId = newActiveCircleId;
        _activeCircleName = null;
        _meetupId = null;
        _meetupLocation = null;
        _meetupName = null;
        _meetupHasAgreed = false;
        _meetupHasDisagreed = false;
        _meetupAgreedCount = 0;
        _meetupDisagreedCount = 0;
        _routePoints.clear();
      });

      _showMessage('You left the circle');
    } catch (e) {
      _showMessage('Could not leave circle: $e');
    }
  }

  Future<void> _initializeLocation() async {
    await _checkGpsAndFetchLocation();
    unawaited(_startLiveLocation());
  }

  Future<void> _checkGpsAndFetchLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _statusText = 'Turn on GPS/location services');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _statusText = 'Location permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _updateLocation(position);
      if (!widget.isGuest) await _saveLocationToFirestore(position);
    } catch (_) {
      setState(() => _statusText = 'Using default location');
    }
  }

  Future<void> _startLiveLocation() async {
    try {
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      await _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(locationSettings: settings)
          .listen((position) async {
            _updateLocation(position);
            if (!widget.isGuest) await _saveLocationToFirestore(position);
          });
    } catch (e) {
      debugPrint('Live location error: $e');
    }
  }

  void _updateLocation(Position position) {
    if (!mounted) return;
    final live = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = live;
      _locationAccuracy = position.accuracy;
      _statusText = 'Live location ±${position.accuracy.toStringAsFixed(1)} m';
    });
    _mapController.move(_currentLocation, _currentZoom);
  }

  Future<void> _saveLocationToFirestore(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('locations').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _createCircleDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Circle'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Circle name',
            hintText: 'Family',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _createCircle(name);
  }

  Future<void> _createCircle(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('circles').add({
      'name': name,
      'createdBy': user.uid,
      'members': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'circleIds': FieldValue.arrayUnion([doc.id]),
      'activeCircleId': doc.id,
    }, SetOptions(merge: true));
    setState(() {
      _activeCircleId = doc.id;
      _activeCircleName = name;
      _myCircles.add(CircleInfo(id: doc.id, name: name));
    });
    _showMessage('Circle created');
  }

  Future<void> _addMemberDialog() async {
    if (_activeCircleId == null) {
      _showMessage('Create a circle first');
      return;
    }
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Member email',
            hintText: 'family@test.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty) return;
    await _addUserToCircle(email);
  }

  Future<void> _addUserToCircle(String email) async {
    if (_activeCircleId == null) return;
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      _showMessage('No user found with that email');
      return;
    }
    final userDoc = query.docs.first;
    await FirebaseFirestore.instance
        .collection('circles')
        .doc(_activeCircleId)
        .update({
          'members': FieldValue.arrayUnion([userDoc.id]),
        });
    await FirebaseFirestore.instance.collection('users').doc(userDoc.id).set({
      'circleIds': FieldValue.arrayUnion([_activeCircleId]),
      'activeCircleId': _activeCircleId,
    }, SetOptions(merge: true));
    _showMessage('Member added');
  }

  Future<void> _createMeetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _activeCircleId == null) {
      _showMessage('Create or select a circle first');
      return;
    }

    if (_searchedLocation == null) {
      _showMessage('Search a place first');
      return;
    }

    final name = _searchedPlaceName ?? _searchController.text.trim();
    setState(() {
      _meetupLocation = _searchedLocation;
      _meetupName = name;
    });
    final meetupDoc = await FirebaseFirestore.instance
        .collection('meetups')
        .add({
          'circleId': _activeCircleId,
          'createdBy': user.uid,
          'name': name,
          'latitude': _searchedLocation!.latitude,
          'longitude': _searchedLocation!.longitude,
          'agreedBy': [user.uid],
          'disagreedBy': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
    setState(() {
      _meetupId = meetupDoc.id;
    });
    _showMessage('Meetup created');
  }

  Future<void> _agreeMeetup(String meetupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('meetups').doc(meetupId).update(
      {
        'agreedBy': FieldValue.arrayUnion([user.uid]),
        'disagreedBy': FieldValue.arrayRemove([user.uid]),
      },
    );

    if (mounted) {
      setState(() {
        _meetupHasAgreed = true;
        _meetupHasDisagreed = false;
      });
    }
    _showMessage('You agreed to this meetup');
  }

  Future<void> _disagreeMeetup(String meetupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('meetups').doc(meetupId).update(
      {
        'disagreedBy': FieldValue.arrayUnion([user.uid]),
        'agreedBy': FieldValue.arrayRemove([user.uid]),
      },
    );

    if (mounted) {
      setState(() {
        _meetupHasAgreed = false;
        _meetupHasDisagreed = true;
      });
    }
    _showMessage('You disagreed with this meetup');
  }

  Future<void> _getRouteToMeetup(LatLng destination) async {
    final start = _currentLocation;
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      _showMessage('Could not load route');
      return;
    }
    final data = jsonDecode(response.body);
    final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
    setState(() {
      _routePoints = coordinates
          .map((point) => LatLng(point[1].toDouble(), point[0].toDouble()))
          .toList();
    });
    _mapController.move(destination, 14);
  }

  Stream<List<CircleMember>> _circleMembersStream() async* {
    if (_activeCircleId == null) {
      yield [];
      return;
    }
    await for (final circleDoc
        in FirebaseFirestore.instance
            .collection('circles')
            .doc(_activeCircleId)
            .snapshots()) {
      if (!circleDoc.exists) {
        yield [];
        continue;
      }
      final members = List<String>.from(circleDoc.data()?['members'] ?? []);
      if (members.isEmpty) {
        yield [];
        continue;
      }
      final result = <CircleMember>[];
      for (final uid in members) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final locDoc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(uid)
            .get();
        if (!userDoc.exists || !locDoc.exists) continue;
        final userData = userDoc.data()!;
        final locData = locDoc.data()!;
        if (locData['latitude'] == null || locData['longitude'] == null)
          continue;
        result.add(
          CircleMember(
            uid: uid,
            name: userData['name'] ?? 'Member',
            email: userData['email'] ?? '',
            location: LatLng(
              (locData['latitude'] as num).toDouble(),
              (locData['longitude'] as num).toDouble(),
            ),
          ),
        );
      }
      yield result;
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = true);
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) {
        _showMessage('Location not found');
        return;
      }
      final first = results.first;
      final target = LatLng(first.latitude, first.longitude);
      setState(() {
        _searchedLocation = target;
        _searchedPlaceName = query;
        _currentZoom = 16;
      });
      _mapController.move(target, _currentZoom);
    } catch (_) {
      _showMessage('Search failed');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchedLocation = null;
      _searchedPlaceName = null;
    });
  }

  void _recenterMap() => _mapController.move(_currentLocation, _currentZoom);
  void _zoomIn() {
    if (_currentZoom < 19) {
      _currentZoom++;
      _mapController.move(_searchedLocation ?? _currentLocation, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_currentZoom > 3) {
      _currentZoom--;
      _mapController.move(_searchedLocation ?? _currentLocation, _currentZoom);
    }
  }

  Future<void> _logout() async {
    if (widget.isGuest) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _sendSos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'uid': user.uid,
        'email': user.email,
        'circleId': _activeCircleId,
        'latitude': _currentLocation.latitude,
        'longitude': _currentLocation.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    _showMessage('SOS alert sent');
  }

  void _focusOnMember(CircleMember member) {
    setState(() {
      _currentZoom = 17;
    });
    _mapController.move(member.location, _currentZoom);
    _showMessage('Showing ${member.name}');
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  List<Marker> _buildMarkers(List<CircleMember> members) {
    final markers = <Marker>[
      Marker(
        point: _currentLocation,
        width: 70,
        height: 70,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_on, color: Colors.red, size: 48),
      ),
    ];
    for (final member in members) {
      if (member.uid == FirebaseAuth.instance.currentUser?.uid) continue;
      markers.add(
        Marker(
          point: member.location,
          width: 100,
          height: 90,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _focusOnMember(member),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 42),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    member.name,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_meetupLocation != null) {
      markers.add(
        Marker(
          point: _meetupLocation!,
          width: 120,
          height: 90,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {
              if (_meetupId == null) {
                _showMessage('Meetup is loading. Try again.');
                return;
              }
              _showMeetupDetails(
                meetupId: _meetupId!,
                name: _meetupName ?? 'Meetup',
                location: _meetupLocation!,
                hasAgreed: _meetupHasAgreed,
                hasDisagreed: _meetupHasDisagreed,
                agreedCount: _meetupAgreedCount,
                disagreedCount: _meetupDisagreedCount,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flag, color: Colors.purple, size: 42),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _meetupName ?? 'Meetup',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_searchedLocation != null) {
      markers.add(
        Marker(
          point: _searchedLocation!,
          width: 110,
          height: 90,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place, color: Colors.purple, size: 42),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _searchedPlaceName ?? 'Search',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CircleMember>>(
      stream: _circleMembersStream(),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        return Scaffold(
          body: Stack(
            children: [
              _buildMap(members),
              _meetupPanel(),
              Positioned(
                top: 48,
                left: 18,
                right: 18,
                child: _buildSearchBar(),
              ),
              Positioned(
                top: 112,
                left: 18,
                right: 18,
                child: _buildCircleBar(),
              ),
              Positioned(
                right: 18,
                bottom: 202,
                child: Column(
                  children: [
                    _roundButton(
                      _isSatellite ? Icons.map : Icons.layers,
                      () => setState(() => _isSatellite = !_isSatellite),
                    ),
                    const SizedBox(height: 12),
                    _roundButton(Icons.place, _createMeetup),
                    const SizedBox(height: 12),
                    _roundButton(Icons.add, _zoomIn),
                    const SizedBox(height: 12),
                    _roundButton(Icons.remove, _zoomOut),
                    const SizedBox(height: 12),
                    _roundButton(Icons.my_location, _recenterMap),
                    const SizedBox(height: 12),
                    _sosButton(),
                  ],
                ),
              ),
              Positioned(
                top: 178,
                left: 18,
                right: 90,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _familyTray(members),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(List<CircleMember> members) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLocation,
        initialZoom: _currentZoom,
        minZoom: 3,
        maxZoom: 19,
        onPositionChanged: (position, hasGesture) {
          if (position.zoom != null) _currentZoom = position.zoom!;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatellite
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.final_yr_project',
        ),
        PolylineLayer(
          polylines: [
            if (_routePoints.isNotEmpty)
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: Colors.deepPurple,
              ),
          ],
        ),
        MarkerLayer(markers: _buildMarkers(members)),
      ],
    );
  }

  Widget _meetupPanel() {
    if (_activeCircleId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meetups')
          .where('circleId', isEqualTo: _activeCircleId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Positioned(
            left: 20,
            right: 20,
            top: 230,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Meetup error: ${snapshot.error}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_meetupId != null || _meetupLocation != null) {
              setState(() {
                _meetupId = null;
                _meetupLocation = null;
                _meetupName = null;
                _meetupHasAgreed = false;
                _meetupHasDisagreed = false;
                _meetupAgreedCount = 0;
                _meetupDisagreedCount = 0;
                _routePoints.clear();
              });
            }
          });
          return const SizedBox();
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'];
          final bCreated = bData['createdAt'];

          if (aCreated is Timestamp && bCreated is Timestamp) {
            return aCreated.compareTo(bCreated);
          }
          return 0;
        });

        final doc = docs.last;
        final data = doc.data() as Map<String, dynamic>;

        if (data['latitude'] == null || data['longitude'] == null) {
          return const SizedBox();
        }

        final location = LatLng(
          (data['latitude'] as num).toDouble(),
          (data['longitude'] as num).toDouble(),
        );

        final name = (data['name'] ?? 'Meetup').toString();
        final agreedBy = List<String>.from(data['agreedBy'] ?? []);
        final disagreedBy = List<String>.from(data['disagreedBy'] ?? []);
        final user = FirebaseAuth.instance.currentUser;
        final hasAgreed = user != null && agreedBy.contains(user.uid);
        final hasDisagreed = user != null && disagreedBy.contains(user.uid);
        final agreedCount = agreedBy.length;
        final disagreedCount = disagreedBy.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_meetupId != doc.id ||
              _meetupLocation != location ||
              _meetupName != name ||
              _meetupHasAgreed != hasAgreed ||
              _meetupHasDisagreed != hasDisagreed ||
              _meetupAgreedCount != agreedCount ||
              _meetupDisagreedCount != disagreedCount) {
            setState(() {
              _meetupId = doc.id;
              _meetupLocation = location;
              _meetupName = name;
              _meetupHasAgreed = hasAgreed;
              _meetupHasDisagreed = hasDisagreed;
              _meetupAgreedCount = agreedCount;
              _meetupDisagreedCount = disagreedCount;
            });
          }
        });

        return Positioned(
          left: 18,
          right: 90,
          top: 218,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _showMeetupDetails(
                    meetupId: doc.id,
                    name: name,
                    location: location,
                    hasAgreed: hasAgreed,
                    hasDisagreed: hasDisagreed,
                    agreedCount: agreedCount,
                    disagreedCount: disagreedCount,
                  ),
                  child: const Icon(Icons.flag, color: Colors.purple),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Meetup: $name',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: hasAgreed ? null : () => _agreeMeetup(doc.id),
                  child: Text(hasAgreed ? 'Agreed' : 'Agree'),
                ),
                TextButton(
                  onPressed: hasDisagreed
                      ? null
                      : () => _disagreeMeetup(doc.id),
                  child: Text(hasDisagreed ? 'Disagreed' : 'No'),
                ),
                IconButton(
                  tooltip: 'Directions',
                  onPressed: () => _getRouteToMeetup(location),
                  icon: const Icon(Icons.directions_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.50)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _isSearching ? null : _searchLocation,
                icon: _isSearching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF49454F),
                      ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchLocation(),
                  decoration: const InputDecoration(
                    hintText: 'Search places or addresses...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty ||
                  _searchedLocation != null)
                IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.50)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: widget.isGuest
                    ? const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            'Guest',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Active Circle',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _activeCircleId,
                              isExpanded: true,
                              isDense: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              hint: const Text(
                                'No circle yet',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              items: _myCircles
                                  .map(
                                    (circle) => DropdownMenuItem<String>(
                                      value: circle.id,
                                      child: Text(
                                        circle.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (circleId) {
                                if (circleId == null) return;
                                final circle = _myCircles.firstWhere(
                                  (c) => c.id == circleId,
                                );
                                _switchCircle(circle);
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              if (!widget.isGuest) ...[
                _smallActionButton(
                  Icons.group_add_rounded,
                  _createCircleDialog,
                  'Create Circle',
                ),
                const SizedBox(width: 8),
                _smallActionButton(
                  Icons.person_add_alt_1_rounded,
                  _addMemberDialog,
                  'Add Member',
                ),
                const SizedBox(width: 8),
                _circleMoreMenuButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallActionButton(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3EEFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF4F378B), size: 22),
        ),
      ),
    );
  }

  Widget _circleMoreMenuButton() {
    return PopupMenuButton<String>(
      tooltip: 'More circle options',
      onSelected: (value) {
        if (value == 'settings') {
          _openSettings();
        } else if (value == 'leave') {
          _confirmLeaveActiveCircle();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.settings_rounded),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem(
          value: 'leave',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
            title: Text('Leave Circle'),
          ),
        ),
      ],
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF3EEFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          color: Color(0xFF4F378B),
          size: 22,
        ),
      ),
    );
  }

  Widget _familyTray(List<CircleMember> members) {
    return Container(
      height: 198,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 22,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Active Circle: ${_activeCircleName ?? 'No Circle'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 14),
          if (widget.isGuest)
            const Text(
              'Login to create a circle',
              style: TextStyle(color: Colors.black54),
            )
          else if (_activeCircleId == null)
            const Text(
              'Create a circle to add members',
              style: TextStyle(color: Colors.black54),
            )
          else if (members.isEmpty)
            const Text(
              'Waiting for member locations...',
              style: TextStyle(color: Colors.black54),
            )
          else
            SizedBox(
              height: 90,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final isMe =
                      member.uid == FirebaseAuth.instance.currentUser?.uid;
                  return GestureDetector(
                    onTap: () => _focusOnMember(member),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFFE8DEF8)
                                : const Color(0xFFE3F2FD),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: Icon(
                            isMe
                                ? Icons.person_rounded
                                : Icons.person_pin_circle_rounded,
                            color: isMe ? const Color(0xFF6750A4) : Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 78,
                          child: Text(
                            member.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: Color(0xFF2D2934), size: 24),
      ),
    );
  }

  Widget _sosButton() {
    return GestureDetector(
      onTap: _sendSos,
      child: Container(
        height: 64,
        width: 64,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
        ),
        child: const Center(
          child: Text(
            'SOS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool highContrast = false;
  bool largeText = false;
  bool reduceMotion = false;
  bool sosConfirmation = true;

  final user = FirebaseAuth.instance.currentUser;
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccountWarning() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This is a demo safety option. In a production app, this would permanently delete the user account and related data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withOpacity(0.12),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        secondary: CircleAvatar(
          backgroundColor: Colors.deepPurple.withOpacity(0.12),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        value: value,
        activeColor: Colors.deepPurple,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = largeText ? 1.15 : 1.0;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Container(
          color: highContrast ? Colors.black : const Color(0xFFF8F6FF),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: highContrast
                      ? Colors.grey.shade900
                      : Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'Guest User',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: highContrast ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SafeCircle account',
                            style: TextStyle(
                              color: highContrast
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highContrast ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _tile(
                icon: Icons.contact_support,
                title: 'Contact Us',
                subtitle: 'Get help or send feedback',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                  );
                },
              ),
              _tile(
                icon: Icons.accessibility_new,
                title: 'Accessibility',
                subtitle: 'Text size, contrast and motion settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccessibilityScreen(
                        highContrast: highContrast,
                        largeText: largeText,
                        reduceMotion: reduceMotion,
                        onChanged: (contrast, text, motion) {
                          setState(() {
                            highContrast = contrast;
                            largeText = text;
                            reduceMotion = motion;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Safety',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highContrast ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _switchTile(
                icon: Icons.warning_amber,
                title: 'SOS Confirmation',
                subtitle: 'Ask before sending SOS alert',
                value: sosConfirmation,
                onChanged: (value) {
                  setState(() => sosConfirmation = value);
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Privacy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: highContrast ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _tile(
                icon: Icons.privacy_tip,
                title: 'Privacy Notice',
                subtitle: 'Location is only shared with circle members',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Privacy Notice'),
                      content: const Text(
                        'SafeCircle stores your location in Firebase Firestore so circle members can view your live position.\nThis is a prototype and should use stronger production security rules before public release.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _tile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                subtitle: 'Demo warning only',
                onTap: _deleteAccountWarning,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final subjectController = TextEditingController();
  final messageController = TextEditingController();

  bool loading = false;
  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final subject = subjectController.text.trim();
    final message = messageController.text.trim();

    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter subject and message')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance.collection('contact_messages').add({
        'uid': user?.uid,
        'email': user?.email ?? 'guest',
        'subject': subject,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
      subjectController.clear();
      messageController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.support_agent, size: 70, color: Colors.deepPurple),
          const SizedBox(height: 12),
          const Text(
            'Need help?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Send feedback or report an issue. Your message will be saved in Firestore.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.email, color: Colors.deepPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user?.email ?? 'Guest user',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: subjectController,
            decoration: _decoration('Subject', Icons.title),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: messageController,
            maxLines: 6,
            decoration: _decoration('Message', Icons.message),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _sendMessage,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(loading ? 'Sending...' : 'Send Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccessibilityScreen extends StatefulWidget {
  final bool highContrast;
  final bool largeText;
  final bool reduceMotion;
  final void Function(bool highContrast, bool largeText, bool reduceMotion)
  onChanged;
  const AccessibilityScreen({
    super.key,
    required this.highContrast,
    required this.largeText,
    required this.reduceMotion,
    required this.onChanged,
  });
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  late bool highContrast;
  late bool largeText;
  late bool reduceMotion;

  @override
  void initState() {
    super.initState();
    highContrast = widget.highContrast;
    largeText = widget.largeText;
    reduceMotion = widget.reduceMotion;
  }

  void _update() {
    widget.onChanged(highContrast, largeText, reduceMotion);
  }

  Widget _accessSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      color: highContrast ? Colors.grey.shade900 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        secondary: CircleAvatar(
          backgroundColor: Colors.deepPurple.withOpacity(0.12),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highContrast ? Colors.white : Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: highContrast ? Colors.white70 : Colors.black54,
          ),
        ),
        value: value,
        activeColor: Colors.deepPurple,
        onChanged: (newValue) {
          setState(() => onChanged(newValue));
          _update();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScale = largeText ? 1.2 : 1.0;
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        backgroundColor: highContrast ? Colors.black : Colors.white,
        appBar: AppBar(
          title: const Text('Accessibility'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.accessibility_new,
              size: 70,
              color: highContrast ? Colors.white : Colors.deepPurple,
            ),
            const SizedBox(height: 12),
            Text(
              'Accessibility Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: highContrast ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adjust the app to make it easier to read and use.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: highContrast ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _accessSwitch(
              icon: Icons.contrast,
              title: 'High Contrast',
              subtitle: 'Improve readability with stronger contrast',
              value: highContrast,
              onChanged: (value) => highContrast = value,
            ),
            _accessSwitch(
              icon: Icons.text_fields,
              title: 'Large Text',
              subtitle: 'Increase text size across settings screens',
              value: largeText,
              onChanged: (value) => largeText = value,
            ),
            _accessSwitch(
              icon: Icons.motion_photos_off,
              title: 'Reduce Motion',
              subtitle: 'Reduce unnecessary animations',
              value: reduceMotion,
              onChanged: (value) => reduceMotion = value,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: highContrast
                    ? Colors.grey.shade900
                    : Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Preview text: SafeCircle helps users share location safely with trusted circle members.',
                style: TextStyle(
                  fontSize: largeText ? 18 : 15,
                  color: highContrast ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
