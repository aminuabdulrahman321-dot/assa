import 'package:flutter/material.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/core/utils/helpers.dart';
import 'package:assa/services/notification_service.dart';
import 'package:assa/widgets/common/common_widgets.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});
  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _notif = NotificationService();
  bool _isLoading = false;
  String _targetAudience = 'all'; // 'all', 'users', 'drivers'

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      Helpers.showErrorSnackBar(context, 'Please fill in both fields.');
      return;
    }
    setState(() => _isLoading = true);

    bool success;
    if (_targetAudience == 'all') {
      success = await _notif.broadcastToAllUsers(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        type: 'general',
      );
    } else {
      success = await _notif.broadcastToRole(
        role: _targetAudience,
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        type: 'general',
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      final label = _targetAudience == 'all'
          ? 'all users & drivers'
          : '${_targetAudience}s';
      Helpers.showSuccessSnackBar(context, 'Notification sent to $label!');
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } else {
      Helpers.showErrorSnackBar(context, 'Failed to send notification. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'Sending notification...',
        child: SafeArea(
          child: Column(children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.adminColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.adminColor.withOpacity(0.2)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.adminColor, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Notifications are written to Firestore and appear instantly in the app for every recipient.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Audience selector
                    const Text('Send To',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _AudienceChip(
                        label: 'Everyone',
                        icon: Icons.people_rounded,
                        selected: _targetAudience == 'all',
                        onTap: () => setState(() => _targetAudience = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _AudienceChip(
                        label: 'Users only',
                        icon: Icons.person_rounded,
                        selected: _targetAudience == 'user',
                        onTap: () => setState(() => _targetAudience = 'user'),
                      ),
                      const SizedBox(width: 8),
                      _AudienceChip(
                        label: 'Drivers only',
                        icon: Icons.drive_eta_rounded,
                        selected: _targetAudience == 'driver',
                        onTap: () => setState(() => _targetAudience = 'driver'),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // Title field
                    CustomTextField(
                      label: 'Notification Title',
                      hint: 'e.g. Shuttle Delay Notice',
                      controller: _titleCtrl,
                      prefixIcon: Icons.title_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Body field
                    CustomTextField(
                      label: 'Message',
                      hint: 'Write your notification message here...',
                      controller: _bodyCtrl,
                      prefixIcon: Icons.message_rounded,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 32),

                    CustomButton(
                      text: 'Broadcast Notification',
                      onPressed: _send,
                      isLoading: _isLoading,
                      backgroundColor: AppColors.adminColor,
                      icon: Icons.notifications_rounded,
                    ),
                  ],
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Send Notification',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Broadcast to users & drivers',
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
            ])),
        const Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
      ]),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _AudienceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.adminColor : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected
                    ? AppColors.adminColor
                    : AppColors.cardBorder),
          ),
          child: Column(children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}