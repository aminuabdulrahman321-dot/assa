import 'package:flutter/material.dart';
import 'package:assa/core/constants/app_colors.dart';

// ════════════════════════════════════════════════════════════════════
// CUSTOM BUTTON
// ════════════════════════════════════════════════════════════════════

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: isOutlined
          ? OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: backgroundColor ?? AppColors.primary,
          side: BorderSide(
            color: backgroundColor ?? AppColors.primary,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _buildChild(),
      )
          : ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _buildChild(),
      ),
    );
  }

  Widget _buildChild() {
    if (isLoading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.white,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isOutlined
            ? (backgroundColor ?? AppColors.primary)
            : (textColor ?? Colors.white),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// CUSTOM TEXT FIELD
// ════════════════════════════════════════════════════════════════════

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword ? _obscureText : false,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      textCapitalization: widget.textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 20, color: AppColors.textSecondary)
            : null,
        suffixIcon: widget.isPassword
            ? IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          onPressed: () =>
              setState(() => _obscureText = !_obscureText),
        )
            : widget.suffix,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// LOADING OVERLAY
// ════════════════════════════════════════════════════════════════════

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// OFFLINE BANNER
// ════════════════════════════════════════════════════════════════════

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: const Color(0xFFF57F17),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Offline Mode — Limited features available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ROLE BADGE
// ════════════════════════════════════════════════════════════════════

class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({super.key, required this.role});

  Color get _color {
    switch (role) {
      case 'admin':
        return AppColors.adminColor;
      case 'driver':
        return AppColors.driverColor;
      default:
        return AppColors.userColor;
    }
  }

  Color get _lightColor {
    switch (role) {
      case 'admin':
        return AppColors.adminLight;
      case 'driver':
        return AppColors.driverLight;
      default:
        return AppColors.userLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ════════════════════════════════════════════════════════════════════

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'confirmed':
        return AppColors.approvedColor;
      case 'rejected':
      case 'cancelled':
        return AppColors.rejectedColor;
      default:
        return AppColors.pendingColor;
    }
  }

  Color get _lightColor {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'confirmed':
        return AppColors.approvedLight;
      case 'rejected':
      case 'cancelled':
        return AppColors.rejectedLight;
      default:
        return AppColors.pendingLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _lightColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 1,
        ),
      ),
    );
  }
}