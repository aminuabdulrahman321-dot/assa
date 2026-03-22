import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class Helpers {
  Helpers._();

  // ── Greeting ───────────────────────────────────────────────────────
  static String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  // ── Date & Time Formatting ─────────────────────────────────────────
  static String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) return formatDate(dateTime);
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  // ── Role UI Helpers ────────────────────────────────────────────────
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case AppStrings.roleAdmin:
        return AppColors.adminColor;
      case AppStrings.roleDriver:
        return AppColors.driverColor;
      case AppStrings.roleUser:
      default:
        return AppColors.userColor;
    }
  }

  static Color getRoleLightColor(String role) {
    switch (role.toLowerCase()) {
      case AppStrings.roleAdmin:
        return AppColors.adminLight;
      case AppStrings.roleDriver:
        return AppColors.driverLight;
      case AppStrings.roleUser:
      default:
        return AppColors.userLight;
    }
  }

  static IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case AppStrings.roleAdmin:
        return Icons.admin_panel_settings_rounded;
      case AppStrings.roleDriver:
        return Icons.drive_eta_rounded;
      case AppStrings.roleUser:
      default:
        return Icons.person_rounded;
    }
  }

  // ── Status UI Helpers ──────────────────────────────────────────────
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pendingColor;
      case 'approved':
      case 'confirmed':
        return AppColors.approvedColor;
      case 'rejected':
      case 'cancelled':
        return AppColors.rejectedColor;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color getStatusLightColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pendingLight;
      case 'approved':
      case 'confirmed':
        return AppColors.approvedLight;
      case 'rejected':
      case 'cancelled':
        return AppColors.rejectedLight;
      default:
        return AppColors.surfaceVariant;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // ── SnackBar Helpers ───────────────────────────────────────────────
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Dialog Helpers ─────────────────────────────────────────────────
  static Future<bool?> showConfirmDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
        Color? confirmColor,
      }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? AppColors.primary,
              minimumSize: const Size(80, 40),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ── String Helpers ─────────────────────────────────────────────────
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}