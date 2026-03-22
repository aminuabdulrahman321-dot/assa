class Validators {
  Validators._();

  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != original) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? matricNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Matric number is required';
    }
    // Accepts formats like: AFIT/22/0001, 22/EE/001, etc.
    if (value.trim().length < 5) {
      return 'Please enter a valid matric number';
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.trim().replaceAll(' ', ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? shuttleId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Shuttle ID is required';
    }
    if (value.trim().length < 3) {
      return 'Please enter a valid shuttle ID';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? department(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Department is required';
    }
    return null;
  }
}