import 'package:flutter/material.dart';
import 'package:assa/services/auth_service.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});
  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  bool _isSending = false;
  bool _resentSuccess = false;
  int  _resendCooldown = 0;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _goToLogin() => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false);

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0) return;
    setState(() { _isSending = true; _resentSuccess = false; });
    final result = await _auth.resendVerificationEmail();
    if (mounted) {
      setState(() { _isSending = false; _resentSuccess = result['success'] == true;
      _resendCooldown = 60; });
      if (_resentSuccess) _startCooldown();
    }
  }

  void _startCooldown() async {
    while (_resendCooldown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendCooldown--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                onPressed: _goToLogin,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(children: [
              const SizedBox(height: 20),
              // Animated envelope
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + _pulse.value * 0.06,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.3),
                          width: 2),
                      boxShadow: [BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 20 + _pulse.value * 20,
                          spreadRadius: 4)],
                    ),
                    child: const Center(child: Text('✉️',
                        style: TextStyle(fontSize: 52))),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Welcome to ASSA! 🎉',
                  style: TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Your account has been created successfully.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9),
                      fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text('One last step — verify your email to activate your account.',
                  style: TextStyle(color: Colors.white.withOpacity(0.75),
                      fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text('We sent a verification link to',
                  style: TextStyle(color: Colors.white.withOpacity(0.8),
                      fontSize: 14)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(widget.email,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              const SizedBox(height: 32),
              // Steps card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20, offset: const Offset(0, 8))],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _Step(n: '1', icon: '📬',
                      text: 'Open your email inbox or Spam/Junk folder'),
                  const SizedBox(height: 14),
                  _Step(n: '2', icon: '🔗',
                      text: 'Click the verification link from ASSA'),
                  const SizedBox(height: 14),
                  _Step(n: '3', icon: '🚐',
                      text: 'Return here, sign in and start booking rides!'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCC02)),
                    ),
                    child: const Row(children: [
                      Text('⚠️', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Not seeing the email? Check your Spam or Junk folder. Mark it as "Not Spam" so future emails go to your inbox.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.5),
                      )),
                    ]),
                  ),
                  if (_resentSuccess) ...[ const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF00C853).withOpacity(0.3))),
                      child: const Row(children: [
                        Icon(Icons.check_circle_rounded,
                            color: Color(0xFF00C853), size: 18),
                        SizedBox(width: 8),
                        Text('Verification email resent!',
                            style: TextStyle(color: Color(0xFF00C853),
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 28),
              // Resend button
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _resendCooldown > 0 ? null
                      : _isSending ? null : _resendEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.white.withOpacity(0.5))),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : '📤  Resend Email',
                      style: const TextStyle(fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text("✓  I've Verified — Sign In",
                      style: TextStyle(fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              ),
            ]),
          )),
        ])),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n, icon, text;
  const _Step({required this.n, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 36, height: 36,
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]),
            borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(n,
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.w900, fontSize: 14)))),
    const SizedBox(width: 12),
    Text(icon, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 8),
    Expanded(child: Text(text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600))),
  ]);
}