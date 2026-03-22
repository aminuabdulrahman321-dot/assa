import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:assa/widgets/common/ad_overlay.dart';
import 'package:assa/services/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/core/utils/helpers.dart';
import 'package:assa/services/auth_service.dart';
import 'package:assa/services/connectivity_service.dart';
import 'package:assa/widgets/common/common_widgets.dart';
import 'package:assa/screens/auth/login_screen.dart';
import 'package:assa/screens/user/my_requests_screen.dart';
import 'package:assa/screens/user/request_screen.dart';
import 'package:assa/screens/user/notifications_screen.dart';
import 'package:assa/screens/user/user_settings_screen.dart';
import 'package:assa/screens/user/report_screen.dart';
import 'package:assa/screens/user/puzzle_screen.dart';
import 'package:assa/screens/user/lost_found_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});
  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  final _auth         = AuthService();
  final _connectivity = ConnectivityService();
  Map<String, dynamic>? _userData;
  bool _isOnline  = true;
  bool _isLoading = true;
  bool _bannerDismissed     = false;
  bool _howToBookDismissed  = false;
  int  _unreadNotifications  = 0;
  int  _availableCredits     = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivity.checkConnectivity().then((v) {
      if (mounted) setState(() => _isOnline = v);
    });
    _connectivity.connectionStream.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      Map<String, dynamic>? data = doc.data();

      // ── Migration: generate pickupId for existing users who don't have one ──
      if (data != null && (data['pickupId'] == null || (data['pickupId'] as String).isEmpty)) {
        final pickupId = _generatePickupId(uid);
        await FirebaseFirestore.instance
            .collection('users').doc(uid).update({'pickupId': pickupId});
        data = {...data, 'pickupId': pickupId};
      }

      if (mounted) setState(() {
        _userData  = data;
        _isLoading = false;
      });
      _listenToNotifications(uid);
      _listenToCredits(uid);
      NotificationService.instance.attachRideListener(uid);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Deterministic fallback: derives a 3-char pickupId from the uid
  /// so the same user always gets the same ID even without a server round-trip.
  /// Format: 1 letter + 2 digits  e.g. K47
  String _generatePickupId(String uid) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final hash = uid.codeUnits.fold(0, (a, b) => a * 31 + b);
    final letter = letters[hash.abs() % letters.length];
    final digits = (hash.abs() % 100).toString().padLeft(2, '0');
    return '$letter$digits';
  }

  void _listenToNotifications(String uid) {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _unreadNotifications = snap.docs.length);
    });
  }

  void _listenToCredits(String uid) {
    FirebaseFirestore.instance
        .collection('ride_credits')
        .where('userId', isEqualTo: uid)
        .where('used', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        final total = snap.docs.fold<int>(
            0, (sum, d) => sum + ((d.data())['amount'] as int? ?? 0));
        setState(() => _availableCredits = total);
      }
    });
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => UserSettingsScreen(
          userData: _userData, onLogout: _logout),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final name = _userData?['name'] ?? 'User';
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdOverlayWrapper(child: SafeArea(
        child: Column(children: [
          if (!_isOnline) const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(name),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: _buildPickupIdCard(),
                      ),
                      if (_availableCredits > 0) ...[
                        const SizedBox(height: 12),
                        _buildCreditsStrip(),
                      ],
                      const SizedBox(height: 16),
                      _buildActiveBookingBanner(uid),
                      _buildAdBanner(),
                      _buildHowToBook(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Quick Actions', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                              const SizedBox(height: 16),
                              _buildQuickActions(),
                              const SizedBox(height: 20),
                            ]),
                      ),
                    ]),
              ),
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2)),
            child: Center(child: Text(Helpers.getInitials(name),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Helpers.getGreeting(),
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w700)),
              ])),

          Stack(children: [
            IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              icon: const Icon(Icons.notifications_rounded,
                  color: Colors.white, size: 26),
            ),
            if (_unreadNotifications > 0)
              Positioned(top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Center(child: Text('$_unreadNotifications',
                        style: const TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.w700))),
                  )),
          ]),
          IconButton(onPressed: _openSettings,
              icon: const Icon(Icons.settings_rounded,
                  color: Colors.white, size: 26)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: _isOnline ? Colors.greenAccent : Colors.orange)),
            const SizedBox(width: 6),
            Text(_isOnline ? 'Online' : 'Offline Mode',
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPickupIdCard() {
    final pickupId = (_userData?['pickupId'] as String?) ?? '---';
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0D47A1).withOpacity(0.35),
              blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.badge_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR PICKUP ID',
              style: TextStyle(
                  color: Colors.white70, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(pickupId,
              style: const TextStyle(
                  color: Colors.white, fontSize: 32,
                  fontWeight: FontWeight.w900, letterSpacing: 6)),
          const SizedBox(height: 2),
          const Text(
              'Show this ID to your driver — or listen for it when the shuttle arrives',
              style: TextStyle(color: Colors.white60, fontSize: 10, height: 1.4)),
        ])),
        GestureDetector(
          onTap: () {
            // Copy to clipboard
            final data = ClipboardData(text: pickupId);
            Clipboard.setData(data);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pickup ID copied to clipboard'),
                  duration: Duration(seconds: 2)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.copy_rounded,
                color: Colors.white70, size: 18),
          ),
        ),
      ]),
    );
  }

  // Ride credits strip — shown when user has unused credits from Lost & Found
  Widget _buildCreditsStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00695C)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF00897B).withOpacity(0.25),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ride Credits Available',
                  style: TextStyle(color: Colors.white70, fontSize: 10,
                      fontWeight: FontWeight.w600)),
              Text('$_availableCredits pts',
                  style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ])),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UserLostFoundScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
            child: const Text('View', style: TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _buildActiveBookingBanner(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: [0, 1, 2, 3])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        // Sort in memory
        docs.sort((a, b) {
          final at = (a.data() as Map)['timestamp'];
          final bt = (b.data() as Map)['timestamp'];
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return (bt as Timestamp).compareTo(at as Timestamp);
        });
        final data    = docs.first.data() as Map<String, dynamic>;
        final docId   = docs.first.id;
        final statusCode = data['status'] ?? 0;
        final statusName = data['statusName'] ?? 'Pending';
        final origin     = data['pickupLocation'] ?? data['origin'] ?? '';
        final dest       = data['destination'] ?? '';
        final shuttleId  = data['shuttleIdFeedback'] ?? '';

        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.success.withOpacity(0.9), AppColors.success]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const Icon(Icons.directions_bus_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Ride Active',
                          style: TextStyle(color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(statusName,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('$origin → $dest',
                        style: const TextStyle(
                            color: Color(0xDDFFFFFF), fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    if (shuttleId.isNotEmpty)
                      Text('Shuttle: $shuttleId',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w700)),
                  ])),
              GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancel Ride?'),
                      content: const Text('Are you sure you want to cancel?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes, Cancel',
                                style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await FirebaseFirestore.instance
                        .collection('ride_requests').doc(docId)
                        .update({'status': 5, 'statusName': 'Cancelled'});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ride cancelled.'),
                              backgroundColor: AppColors.error));
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildAdBanner() {
    if (_bannerDismissed) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs
            .cast<DocumentSnapshot>()
            .take(5)
            .toList();
        return Stack(children: [
          _AdCarousel(docs: docs),
          Positioned(top: 8, right: 24,
            child: GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildHowToBook() {
    if (_howToBookDismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color:        AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        const Expanded(child: Text(
          'Tap "Book a Ride" to request a shuttle. '
              'Use Online mode when connected, or Offline mode via campus hotspot.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
        )),
        GestureDetector(
          onTap: () => setState(() => _howToBookDismissed = true),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.close_rounded, size: 16, color: AppColors.textHint),
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount:  2,
      shrinkWrap:      true,
      physics:         const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing:  12,
      childAspectRatio: 1.35,
      children: [
        _ActionCard(
          title:    'Book a Ride',
          subtitle: 'Request a shuttle',
          icon:     Icons.airport_shuttle_rounded,
          color:    AppColors.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const RequestScreen())),
        ),
        _ActionCard(
          title:    'My Requests',
          subtitle: 'View history',
          icon:     Icons.list_alt_rounded,
          color:    AppColors.accent,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen())),
        ),
        _ActionCard(
          title:    'Puzzle Game',
          subtitle: 'Earn leaderboard points',
          icon:     Icons.grid_view_rounded,
          color:    const Color(0xFF6A1B9A),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PuzzleScreen())),
        ),
        _ActionCard(
          title:    'Lost & Found',
          subtitle: _availableCredits > 0
              ? '$_availableCredits credits available'
              : 'Earn ride credits',
          icon:     Icons.volunteer_activism_rounded,
          color:    const Color(0xFF00897B),
          badge:    _availableCredits > 0 ? '$_availableCredits pts' : null,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const UserLostFoundScreen())),
        ),
        _ActionCard(
          title:    'Notifications',
          subtitle: _unreadNotifications > 0
              ? '$_unreadNotifications unread' : 'All caught up',
          icon:     Icons.notifications_active_rounded,
          color:    AppColors.warning,
          badge:    _unreadNotifications > 0 ? '$_unreadNotifications' : null,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),

        _ActionCard(
          title:    'Complaint Panel',
          subtitle: 'Chat with support',
          icon:     Icons.support_agent_rounded,
          color:    AppColors.error,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) =>
                  ReportScreen(userData: _userData))),
        ),
      ],
    );
  }
}

// ── UUID Card ──────────────────────────────────────────────────────────
class _UuidCard extends StatelessWidget {
  final String label, uuid;
  final Color  color;
  final IconData icon;
  const _UuidCard({required this.label, required this.uuid,
    required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: color, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 6),
        Text(uuid, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: color, letterSpacing: 1.5),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ── Action Card ────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final String    title, subtitle;
  final IconData  icon;
  final Color     color;
  final VoidCallback onTap;
  final String?   badge;
  const _ActionCard({required this.title, required this.subtitle,
    required this.icon, required this.color,
    required this.onTap, this.badge});

  // Derive a darker shade for the gradient
  Color get _dark => Color.fromARGB(
    255,
    (color.red   * 0.65).round().clamp(0, 255),
    (color.green * 0.65).round().clamp(0, 255),
    (color.blue  * 0.65).round().clamp(0, 255),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.28),
                blurRadius: 14, offset: const Offset(0, 6)),
            BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, _dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative circle top-right
            Positioned(
              right: -18, top: -18,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
            ),
            // Decorative circle bottom-left
            Positioned(
              left: -10, bottom: -20,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large icon container
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5),
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                      const Spacer(),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                          child: Text(badge!, style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black26,
                              blurRadius: 4)])),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withOpacity(0.80),
                          height: 1.3)),
                    ],
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


// ── Conventional Ad Billboard Carousel ────────────────────────────────
// Auto-scrolls every 4s. Full-width card with image area + text overlay.
// Looks like real app store / news app ads.
// ── Ad Carousel ────────────────────────────────────────────────────────
class _AdCarousel extends StatefulWidget {
  final List<DocumentSnapshot> docs;
  const _AdCarousel({required this.docs});
  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  static const _grads = [
    [Color(0xFF1565C0), Color(0xFF1976D2), Color(0xFF42A5F5)],
    [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)],
    [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFF7043)],
    [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF66BB6A)],
  ];
  static const _emojis = ['🚌','📢','🎯','⚡','🌟'];

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    // Record impression for first ad when carousel loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.docs.isNotEmpty) {
        _recordImpression(widget.docs[0].id);
      }
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _recordImpression(String adId) {
    FirebaseFirestore.instance.collection('ads').doc(adId).update({
      'impressions': FieldValue.increment(1),
      'lastSeen':    FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  void _recordTap(String adId) {
    FirebaseFirestore.instance.collection('ads').doc(adId).update({
      'taps':    FieldValue.increment(1),
      'lastTap': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) {
              setState(() => _page = i);
              // Record impression each time a new ad scrolls into view
              _recordImpression(widget.docs[i].id);
            },
            itemCount: widget.docs.length,
            itemBuilder: (_, i) {
              final doc      = widget.docs[i];
              final d        = doc.data() as Map<String, dynamic>;
              final grad     = _grads[i % _grads.length];
              final emoji    = _emojis[i % _emojis.length];
              final imageUrl = d['imageUrl'] ?? '';
              final linkUrl  = d['linkUrl']  ?? '';
              final title    = d['title']    ?? '';
              final body     = d['body']     ?? '';
              return _AdBillboard(
                adId: doc.id,
                title: title, body: body,
                imageUrl: imageUrl, linkUrl: linkUrl,
                grad: grad, emoji: emoji,
                onTap: () => _recordTap(doc.id),
              );
            },
          ),
        ),
        if (widget.docs.length > 1) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.docs.length, (i) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 22 : 7, height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _page == i
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF1565C0).withOpacity(0.25),
                  ),
                ),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ]),
    );
  }
}

// ── Ad Billboard ───────────────────────────────────────────────────────
class _AdBillboard extends StatelessWidget {
  final String       adId;
  final String       title, body, imageUrl, linkUrl, emoji;
  final List<Color>  grad;
  final VoidCallback onTap;
  const _AdBillboard({
    required this.adId,
    required this.title, required this.body,
    required this.imageUrl, required this.linkUrl,
    required this.grad, required this.emoji,
    required this.onTap,
  });

  Future<void> _openLink() async {
    if (linkUrl.trim().isEmpty) return;
    try {
      String safe = linkUrl.trim();
      if (!safe.startsWith('http://') && !safe.startsWith('https://')) {
        safe = 'https://$safe';
      }
      final uri = Uri.parse(safe);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: linkUrl.isNotEmpty ? () { onTap(); _openLink(); } : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: grad[0].withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            // Background: image if available, else gradient
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: grad,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight)),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: grad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)),
                ),
              ),

            // Dark overlay so text is always readable over images
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.15)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

            // Decorative blobs (only when no image)
            if (imageUrl.isEmpty) ...[
              Positioned(right: -30, top: -30, child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)),
              )),
              Positioned(left: -20, bottom: -20, child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)),
              )),
            ],

            // "AD" chip top-right
            Positioned(top: 10, right: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Text('AD', style: TextStyle(
                  color: Colors.white, fontSize: 9,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            )),

            // Link icon top-left if tappable
            if (linkUrl.isNotEmpty)
              Positioned(top: 10, left: 12, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_new_rounded,
                      color: Colors.white, size: 10),
                  SizedBox(width: 3),
                  Text('TAP TO OPEN', style: TextStyle(
                      color: Colors.white, fontSize: 8,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                ]),
              )),

            // Text content bottom
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 60, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imageUrl.isEmpty)
                      Row(children: [
                        Text(emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        const Text('AFIT SHUTTLE',
                            style: TextStyle(color: Colors.white70,
                                fontSize: 9, fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ]),
                    if (imageUrl.isEmpty) const SizedBox(height: 6),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.w900, height: 1.2,
                            shadows: [Shadow(color: Colors.black54,
                                blurRadius: 8)]),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12, height: 1.4,
                              shadows: const [Shadow(color: Colors.black45,
                                  blurRadius: 6)]),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}