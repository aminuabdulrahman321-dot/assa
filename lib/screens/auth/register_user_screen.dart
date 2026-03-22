import 'package:flutter/material.dart';
import 'package:assa/screens/auth/email_verification_screen.dart';
import 'package:assa/screens/auth/otp_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../user/user_dashboard.dart';
import 'login_screen.dart';
import '../../widgets/common/common_widgets.dart';

class RegisterUserScreen extends StatefulWidget {
  final String googleName;
  final String googleEmail;
  final String googleUid; // set when coming from Google sign-in
  const RegisterUserScreen({super.key, this.googleName = '', this.googleEmail = '', this.googleUid = ''});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  final _authService    = AuthService();

  bool _isLoading  = false;
  bool _usePhone   = false; // toggle: email vs phone

  @override
  void initState() {
    super.initState();
    if (widget.googleName.isNotEmpty)  _nameCtrl.text  = widget.googleName;
    if (widget.googleEmail.isNotEmpty) _emailCtrl.text = widget.googleEmail;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passwordCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Google registration — create Firestore doc for Google user ─────
  Future<void> _registerWithGoogle() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your name.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = widget.googleUid;
      final onlineUUID  = AuthService.generateOnlineUUIDStatic(uid);
      final offlineUUID = AuthService.generateOfflineUUIDStatic(uid);
      final pickupId    = await _authService.assignShortId();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid':         uid,
        'name':        _nameCtrl.text.trim(),
        'email':       widget.googleEmail,
        'role':        'user',
        'createdAt':   DateTime.now().toIso8601String(),
        'onlineUUID':  onlineUUID,
        'offlineUUID': offlineUUID,
        'fingerprintEnabled': false,
        'pickupId':    pickupId,
        'authProvider': 'google',
      });
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserDashboard()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Registration failed. Please try again.');
    }
  }

  // ── Email registration ──────────────────────────────────────────────
  Future<void> _registerWithEmail() async {
    // If coming from Google sign-in, use Google registration flow
    if (widget.googleUid.isNotEmpty) {
      await _registerWithGoogle();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _authService.registerUser(
      name:     _nameCtrl.text,
      email:    _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) =>
            EmailVerificationScreen(email: _emailCtrl.text.trim())),
            (route) => false,
      );
    } else {
      _showError(result['error'] ?? 'Registration failed.');
    }
  }

  // ── Phone registration — send OTP ───────────────────────────────────
  Future<void> _registerWithPhone() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    String? capturedVerificationId;

    await _authService.sendPhoneOtp(
      phoneNumber: _phoneCtrl.text.trim(),
      onCodeSent: (verificationId) {
        capturedVerificationId = verificationId;
      },
      onFailed: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showError(error);
        }
      },
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (capturedVerificationId != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OtpScreen(
          verificationId: capturedVerificationId!,
          phoneNumber:    _phoneCtrl.text.trim(),
          name:           _nameCtrl.text.trim(),
          mode:           OtpMode.register,
        ),
      ));
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: _usePhone ? 'Sending OTP...' : 'Creating your account...',
        child: SafeArea(
          child: Column(children: [
            _buildHeader(context),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(key: _formKey, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Account',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Fill in your details to get started',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 24),

                  // ── Role badge ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text('Registering as a User',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Email / Phone toggle ────────────────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() => _usePhone = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_usePhone ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.email_outlined, size: 16,
                                        color: !_usePhone ? Colors.white : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Email', style: TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: !_usePhone ? Colors.white : Colors.grey)),
                                  ]),
                            ),
                          )),
                          Expanded(child: Opacity(
                            opacity: 0.45,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 16,
                                        color: Colors.grey),
                                    const SizedBox(width: 6),
                                    const Text('Phone', style: TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey)),
                                  ]),
                            ),
                          )),
                        ]),
                      ),
                      Positioned(
                        top: -10, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Coming Soon',
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Name (always shown) ─────────────────────────────
                  CustomTextField(
                    label: 'Full Name', hint: 'Enter your full name',
                    controller: _nameCtrl,
                    prefixIcon: Icons.person_outline_rounded,
                    validator: Validators.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // ── Email fields ────────────────────────────────────
                  if (!_usePhone) ...[
                    CustomTextField(
                      label: 'Email Address', hint: 'Enter your email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password', hint: 'Create a password',
                      controller: _passwordCtrl, isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Confirm Password', hint: 'Re-enter your password',
                      controller: _confirmCtrl, isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                    ),
                  ],

                  // ── Phone fields ────────────────────────────────────
                  if (_usePhone) ...[
                    CustomTextField(
                      label: 'Phone Number', hint: '080 0000 0000 or +234 800 000 0000',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                        final clean = v.trim().replaceAll(' ','').replaceAll('-','');
                        if (clean.length < 10) return 'Enter a valid phone number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 16,
                            color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          'An OTP will be sent to this number to verify your account.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 32),
                  CustomButton(
                    text: _usePhone ? 'Send OTP' : 'Create Account',
                    onPressed: _usePhone ? _registerWithPhone : _registerWithEmail,
                    isLoading: _isLoading,
                    icon: _usePhone ? Icons.sms_outlined : Icons.person_add_rounded,
                  ),
                  const SizedBox(height: 16),
                  Center(child: TextButton(
                    onPressed: () async {
                      await AuthService().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                      );
                    },
                    child: const Text('Already have an account? Sign In',
                        style: TextStyle(color: AppColors.primary, fontSize: 13)),
                  )),
                ],
              )),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () async {
            // Sign out from Firebase so the incomplete Google account
            // doesn't leave the app in a broken state
            await AuthService().logout();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
        const Text('Register', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }
}