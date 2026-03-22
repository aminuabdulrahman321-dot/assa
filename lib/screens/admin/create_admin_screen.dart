import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/core/utils/validators.dart';
import 'package:assa/core/utils/helpers.dart';
import 'package:assa/services/auth_service.dart';
import 'package:assa/widgets/common/common_widgets.dart';

class CreateAdminScreen extends StatefulWidget {
  const CreateAdminScreen({super.key});
  @override
  State<CreateAdminScreen> createState() => _CreateAdminScreenState();
}

class _CreateAdminScreenState extends State<CreateAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _auth = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final result = await _auth.createAdmin(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      createdByUid: uid,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Helpers.showSuccessSnackBar(context, 'Admin account created!');
      Navigator.pop(context);
    } else {
      Helpers.showErrorSnackBar(
          context, result['error'] ?? 'Failed to create admin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Creating admin...',
        child: SafeArea(
          child: Column(children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.adminColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.adminColor.withOpacity(0.2)),
                      ),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.chevron_right_rounded,
                                color: AppColors.adminColor, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'The new admin will be able to log in immediately with these credentials. Make sure to share the password securely.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.5),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 24),
                    CustomTextField(
                      label: 'Full Name',
                      hint: 'Enter admin name',
                      controller: _nameCtrl,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Email',
                      hint: 'Enter admin email',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      hint: 'Create a strong password',
                      controller: _passCtrl,
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'Create Admin Account',
                      onPressed: _create,
                      isLoading: _isLoading,
                      backgroundColor: AppColors.adminColor,
                      icon: Icons.admin_panel_settings_rounded,
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.adminColor,
          AppColors.adminColor.withOpacity(0.8)
        ]),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
      child: Row(children: [
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20)),
        const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create Admin',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text('Add a new administrator account',
                      style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
                ])),
        const Icon(Icons.admin_panel_settings_rounded,
            color: Colors.white, size: 24),
      ]),
    );
  }
}