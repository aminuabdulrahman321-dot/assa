import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/common_widgets.dart';
import '../auth/login_screen.dart';

class DriverPendingScreen extends StatefulWidget {
  final String status;
  const DriverPendingScreen({super.key, required this.status});
  @override
  State<DriverPendingScreen> createState() => _DriverPendingScreenState();
}

class _DriverPendingScreenState extends State<DriverPendingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool get isPending => widget.status == 'pending';

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final grad = isPending
        ? [const Color(0xFFE65100), const Color(0xFFFF6D00)]
        : [const Color(0xFFC62828), const Color(0xFFE53935)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            grad[0].withOpacity(0.12),
            Colors.white,
            Colors.white,
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(children: [
            // Header strip
            Container(
              width: double.infinity, height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
              ),
            ),
            Expanded(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated status icon
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (_, __) => Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: grad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        boxShadow: [BoxShadow(
                            color: grad[0].withOpacity(0.3 + _anim.value * 0.2),
                            blurRadius: 20 + _anim.value * 15,
                            spreadRadius: 2)],
                      ),
                      child: Icon(
                          isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.block_rounded,
                          size: 56, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Big status label
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: grad),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        isPending ? '⏳  UNDER REVIEW' : '🚫  NOT APPROVED',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isPending ? 'Account Pending Approval'
                        : 'Account Not Approved',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w900, color: Color(0xFF1A1A2E),
                        height: 1.2),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Text(
                      isPending
                          ? 'Your driver application is currently being reviewed by the ASSA admin team. You\'ll receive a notification once your account is approved.'
                          : 'Your driver registration was not approved. Please contact the ASSA admin for more information about next steps.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14,
                          color: Color(0xFF555577), height: 1.7),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFE65100).withOpacity(0.3)),
                      ),
                      child: const Row(children: [
                        Text('💡', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                            'This usually takes 24–48 hours. Check your notifications.',
                            style: TextStyle(fontSize: 12,
                                color: Color(0xFFBF360C), height: 1.5))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                                  (r) => false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: grad[0],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Back to Login',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            )),
          ]),
        ),
      ),
    );
  }
}