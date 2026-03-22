import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:assa/screens/auth/email_verification_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/common_widgets.dart';
import '../driver/driver_pending_screen.dart';

class RegisterDriverScreen extends StatefulWidget {
  final String googleName;
  final String googleEmail;
  final String googleUid;
  const RegisterDriverScreen({super.key, this.googleName = '', this.googleEmail = '', this.googleUid = ''});

  @override
  State<RegisterDriverScreen> createState() => _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends State<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.googleName.isNotEmpty) _nameController.text = widget.googleName;
    if (widget.googleEmail.isNotEmpty) _emailController.text = widget.googleEmail;
  }
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _shuttleIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String _loadingMessage = 'Creating your account...';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shuttleIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Creating your account...';
    });

    // Google user — create Firestore doc directly without creating new Auth account
    if (widget.googleUid.isNotEmpty) {
      try {
        final uid = widget.googleUid;
        final onlineUUID  = AuthService.generateOnlineUUIDStatic(uid);
        final offlineUUID = AuthService.generateOfflineUUIDStatic(uid);
        final pickupId    = await _authService.assignShortId();
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid':         uid,
          'name':        _nameController.text.trim(),
          'email':       widget.googleEmail,
          'role':        'driver',
          'status':      'pending',
          'phoneNumber': _phoneController.text.trim(),
          'shuttleId':   _shuttleIdController.text.trim(),
          'createdAt':   DateTime.now().toIso8601String(),
          'onlineUUID':  onlineUUID,
          'offlineUUID': offlineUUID,
          'fingerprintEnabled': false,
          'pickupId':    pickupId,
          'authProvider': 'google',
          'driverIdCardUrl': '',
        });
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DriverPendingScreen(status: 'pending')),
              (route) => false,
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Registration failed. Please try again.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }

    // First create auth account to get UID
    final tempResult = await _authService.registerDriver(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phoneNumber: _phoneController.text,
      shuttleId: _shuttleIdController.text,
      driverIdCardUrl: '',
    );

    if (!mounted) return;

    if (!tempResult['success']) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tempResult['error'] ?? 'Registration failed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final driver = tempResult['driver'];
    if (!mounted) return;
    setState(() => _isLoading = false);

    final driverEmail = driver.email ?? _emailController.text.trim();
    // Always go to email verification first, then they'll see pending after login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(email: driverEmail),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: _loadingMessage,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver Registration',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your account will be reviewed by admin',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Role indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.driverLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                AppColors.driverColor.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.drive_eta_rounded,
                                  color: AppColors.driverColor, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'Registering as a Driver',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.driverColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        CustomTextField(
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          controller: _nameController,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: Validators.name,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Email Address',
                          hint: 'Enter your email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.email_outlined,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Phone Number',
                          hint: 'e.g. 08012345678',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          validator: Validators.phoneNumber,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Shuttle ID',
                          hint: 'Enter your shuttle ID',
                          controller: _shuttleIdController,
                          prefixIcon: Icons.directions_bus_outlined,
                          validator: Validators.shuttleId,
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 16),


                        CustomTextField(
                          label: 'Password',
                          hint: 'Create a password',
                          controller: _passwordController,
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          prefixIcon: Icons.lock_outline_rounded,
                          validator: (value) => Validators.confirmPassword(
                            value,
                            _passwordController.text,
                          ),
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: 'Submit for Review',
                          onPressed: _register,
                          isLoading: _isLoading,
                          backgroundColor: AppColors.driverColor,
                          icon: Icons.send_rounded,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Already have an account? Sign In',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.driverColor,
            AppColors.driverColor.withOpacity(0.8)
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
              );
            },
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Driver Registration',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}