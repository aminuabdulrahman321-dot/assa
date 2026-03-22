class AppStrings {
  AppStrings._();

  // ── App Info ──────────────────────────────────────────────────────
  static const String appName = 'ASSA';
  static const String appFullName = 'AFIT Shuttle Service App';
  static const String appTagline = 'Your campus ride, simplified.';
  static const String appVersion = '1.0.0';
  static const String institution = 'Air Force Institute of Technology';

  // ── Auth ──────────────────────────────────────────────────────────
  static const String login = 'Log In';
  static const String logout = 'Log Out';
  static const String register = 'Register';
  static const String createAccount = 'Create Account';
  static const String emailAddress = 'Email Address';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String dontHaveAccount = "Don't have an account? ";
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';

  // ── Roles ─────────────────────────────────────────────────────────
  static const String admin = 'Admin';
  static const String user = 'User';
  static const String driver = 'Driver';
  static const String roleAdmin = 'admin';
  static const String roleUser = 'user';
  static const String roleDriver = 'driver';

  // ── Registration ──────────────────────────────────────────────────
  static const String fullName = 'Full Name';
  static const String matricNumber = 'Matric Number';
  static const String department = 'Department';
  static const String phoneNumber = 'Phone Number';
  static const String shuttleId = 'Shuttle ID';
  static const String driverIdCard = 'Driver ID Card';
  static const String uploadShuttleId = 'Upload Shuttle ID Image';
  static const String tapToUpload = 'Tap to upload image';
  static const String registerAsUser = 'Register as User';
  static const String registerAsDriver = 'Register as Driver';
  static const String selectRole = 'Select your role to continue';

  // ── Driver Status ─────────────────────────────────────────────────
  static const String pending = 'Pending';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
  static const String pendingApproval = 'Account Pending Approval';
  static const String pendingApprovalMsg =
      'Your driver account is under review. You will be notified once approved by an admin.';
  static const String rejectedMsg =
      'Your driver registration was not approved. Please contact the admin for more information.';

  // ── Dashboards ────────────────────────────────────────────────────
  static const String adminDashboard = 'Admin Dashboard';
  static const String userDashboard = 'My Dashboard';
  static const String driverDashboard = 'Driver Dashboard';
  static const String welcomeBack = 'Welcome back';
  static const String goodMorning = 'Good morning';
  static const String goodAfternoon = 'Good afternoon';
  static const String goodEvening = 'Good evening';

  // ── Bookings ──────────────────────────────────────────────────────
  static const String bookSeat = 'Book a Seat';
  static const String myBookings = 'My Bookings';
  static const String bookingHistory = 'Booking History';
  static const String availableRoutes = 'Available Routes';
  static const String selectRoute = 'Select Route';
  static const String confirmBooking = 'Confirm Booking';
  static const String bookingConfirmed = 'Booking Confirmed!';
  static const String bookingCancelled = 'Booking Cancelled';
  static const String noBookings = 'No bookings yet';
  static const String noRoutes = 'No routes available';
  static const String seatNumber = 'Seat Number';
  static const String availableSeats = 'Available Seats';
  static const String fullyBooked = 'Fully Booked';
  static const String offlineBookingQueued =
      'You are offline. Booking request has been queued and will sync when you reconnect.';

  // ── Routes ────────────────────────────────────────────────────────
  static const String routeName = 'Route Name';
  static const String origin = 'Origin';
  static const String destination = 'Destination';
  static const String departureTime = 'Departure Time';
  static const String totalSeats = 'Total Seats';
  static const String manageRoutes = 'Manage Routes';
  static const String addRoute = 'Add Route';
  static const String editRoute = 'Edit Route';

  // ── Admin ─────────────────────────────────────────────────────────
  static const String manageDrivers = 'Manage Drivers';
  static const String manageBookings = 'Manage Bookings';
  static const String createAdmin = 'Create Admin';
  static const String pendingDrivers = 'Pending Drivers';
  static const String approveDriver = 'Approve';
  static const String rejectDriver = 'Reject';
  static const String totalUsers = 'Total Users';
  static const String totalDrivers = 'Total Drivers';
  static const String totalBookings = 'Total Bookings';
  static const String activeRoutes = 'Active Routes';

  // ── Notifications ─────────────────────────────────────────────────
  static const String notifications = 'Notifications';
  static const String noNotifications = 'No notifications yet';
  static const String markAllRead = 'Mark all as read';

  // ── Connectivity ──────────────────────────────────────────────────
  static const String offlineMode = 'Offline Mode';
  static const String offlineBannerMsg =
      'You\'re offline. Some features are limited.';
  static const String onlineMode = 'Back Online';
  static const String onlineBannerMsg = 'Connection restored. Syncing data...';
  static const String requiresInternet = 'This action requires internet connection.';

  // ── Validation ────────────────────────────────────────────────────
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String passwordTooShort = 'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String invalidMatric = 'Please enter a valid matric number';
  static const String invalidPhone = 'Please enter a valid phone number';

  // ── General ───────────────────────────────────────────────────────
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String view = 'View';
  static const String retry = 'Retry';
  static const String loading = 'Loading...';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String noInternetConnection = 'No internet connection';
  static const String sessionExpired = 'Session expired. Please log in again.';
}