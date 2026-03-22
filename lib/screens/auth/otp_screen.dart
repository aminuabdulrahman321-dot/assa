import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/common_widgets.dart';
import '../user/user_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../driver/driver_pending_screen.dart';
import '../admin/admin_passcode_screen.dart';

enum OtpMode { register, login, passwordReset }

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String name;
  final OtpMode mode;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.name = '',
    required this.mode,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _authService = AuthService();
  final List<TextEditingController> _otpCtrls =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading  = false;
  int  _resendSecs = 60;
  Timer? _timer;
  late String _verificationId;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpCtrls) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _resendSecs = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_resendSecs > 0) _resendSecs--;
        else t.cancel();
      });
    });
  }

  String get _otp => _otpCtrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      _showError('Enter the 6-digit OTP.');
      return;
    }
    setState(() => _isLoading = true);

    Map<String, dynamic> result;

    if (widget.mode == OtpMode.register) {
      result = await _authService.verifyOtpAndRegister(
        verificationId: _verificationId,
        otp:            _otp,
        name:           widget.name,
        phoneNumber:    widget.phoneNumber,
        password:       '',
      );
    } else {
      result = await _authService.verifyOtpAndLogin(
        verificationId: _verificationId,
        otp:            _otp,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final role = result['role'] as String? ?? 'user';
      final uid  = result['uid']  as String? ?? '';
      switch (role) {
        case 'admin':  _goTo(AdminPasscodeScreen(uid: uid)); break;
        case 'driver': _goTo(const DriverDashboard());       break;
        default:       _goTo(const UserDashboard());
      }
    } else {
      _showError(result['error'] ?? 'Verification failed.');
    }
  }

  Future<void> _resend() async {
    if (_resendSecs > 0) return;
    setState(() => _isLoading = true);

    await _authService.sendPhoneOtp(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (id) {
        _verificationId = id;
        if (mounted) {
          setState(() => _isLoading = false);
          _startTimer();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('OTP resent successfully.'),
              behavior: SnackBarBehavior.floating));
        }
      },
      onFailed: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(error);
        }
      },
    );
  }

  void _goTo(Widget screen) => Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen), (r) => false);

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Verifying...',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 32),

                // ── Header ──────────────────────────────────────────
                const Text('Verify your number',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: Color(0xFF0D47A1))),
                const SizedBox(height: 10),
                RichText(text: TextSpan(
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                  children: [
                    const TextSpan(text: 'Enter the 6-digit OTP sent to '),
                    TextSpan(text: widget.phoneNumber,
                        style: const TextStyle(fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1))),
                  ],
                )),
                const SizedBox(height: 40),

                // ── OTP boxes ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _OtpBox(
                    controller: _otpCtrls[i],
                    focusNode:  _focusNodes[i],
                    onChanged: (val) {
                      if (val.isNotEmpty && i < 5) {
                        _focusNodes[i + 1].requestFocus();
                      } else if (val.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      if (_otp.length == 6) _verify();
                    },
                  )),
                ),
                const SizedBox(height: 40),

                // ── Verify button ───────────────────────────────────
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Verify',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Resend ──────────────────────────────────────────
                Center(child: _resendSecs > 0
                    ? Text('Resend OTP in ${_resendSecs}s',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500))
                    : GestureDetector(
                  onTap: _resend,
                  child: const Text('Resend OTP',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1565C0))),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single OTP digit box ────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 56,
      child: TextField(
        controller:   controller,
        focusNode:    focusNode,
        maxLength:    1,
        textAlign:    TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: Color(0xFF0D47A1)),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}