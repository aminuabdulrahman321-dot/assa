import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/services/connectivity_service.dart';
import 'package:assa/services/esp32_service.dart';
import 'package:assa/services/firestore_service.dart';
import 'package:assa/widgets/common/common_widgets.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});
  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final _connectivity     = ConnectivityService();
  final _esp32            = Esp32Service();
  final _firestoreService = FirestoreService();

  String? _selectedPickup;
  String? _selectedDestination;
  String  _selectedRideType = 'Shared';
  int     _passengerCount   = 1;
  bool    _isOnline             = true;
  bool    _isLoading            = false;
  bool    _checkingConnectivity = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkConnectivity();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (mounted) setState(() => _userData = doc.data());
    } catch (_) {}
  }

  Future<void> _checkConnectivity() async {
    final online = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline             = online;
        _checkingConnectivity = false;
        if (!online && _selectedPickup != null) {
          if (!Esp32Service.offlinePickupLocations.contains(_selectedPickup)) {
            _selectedPickup = null;
          }
        }
      });
    }
    _connectivity.connectionStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
        if (!online && _selectedPickup != null) {
          if (!Esp32Service.offlinePickupLocations.contains(_selectedPickup)) {
            _selectedPickup = null;
            _showInfo(
              'You are now in campus WiFi mode. '
                  'Please reselect a hostel pickup point.',
            );
          }
        }
      });
      if (online) _firestoreService.syncOfflineRequests();
    });
  }

  // Online  → all 12 locations as pickup
  // Offline → only 3 hostel ESP32 access points
  List<String> get _pickupLocations => _isOnline
      ? Esp32Service.allLocations
      : Esp32Service.offlinePickupLocations;

  // Destinations always show all 12 regardless of mode
  List<String> get _destinationLocations => Esp32Service.allLocations;

  Future<void> _submitRequest() async {
    if (_selectedPickup == null || _selectedDestination == null) {
      _showError('Please select a pickup point and drop-off area.');
      return;
    }
    if (_selectedPickup == _selectedDestination) {
      _showError('Pickup and destination cannot be the same location.');
      return;
    }
    setState(() => _isLoading = true);
    if (_isOnline) {
      await _submitOnlineRequest();
    } else {
      await _submitOfflineRequest();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submitOnlineRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final success = await _firestoreService.submitOnlineRequest(
      userId:         uid,
      userName:       _userData?['name']       ?? '',
      onlineUUID:     _userData?['onlineUUID'] ?? '',
      pickupLocation: _selectedPickup!,
      destination:    _selectedDestination!,
      rideType:       _selectedRideType,
      passengerCount: _selectedRideType == 'Chartered' ? 1 : _passengerCount,
    );

    if (!mounted) return;
    if (success) {
      _showFeedbackDialog(
        isOnline: true,
        message:  'Your request has been submitted.\n'
            'A driver will be with you shortly.',
      );
    } else {
      _showError('Failed to submit request. Please try again.');
    }
  }

  Future<void> _submitOfflineRequest() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _showError('User not authenticated. Please log in again.');
      return;
    }

    final esp32Connected = await _esp32.isConnectedToEsp32();
    if (!esp32Connected) {
      _showEsp32Dialog();
      return;
    }

    final pickupId = (_userData?['pickupId'] as String?) ?? '';
    if (pickupId.isEmpty) {
      _showError('Pickup ID not found. Please contact admin.');
      setState(() => _isLoading = false);
      return;
    }

    final result = await _esp32.sendRequestToEsp32(
      pickupId:       pickupId,
      pickupLocation: _selectedPickup!,
      destination:    _selectedDestination!,
      rideType:       _selectedRideType,
      passengerCount: _selectedRideType == 'Chartered' ? 1 : _passengerCount,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      await _firestoreService.submitOfflineRequest(
        userId:         uid,
        userName:       _userData?['name']        ?? '',
        offlineUUID:    _userData?['offlineUUID'] ?? uid,
        pickupLocation: _selectedPickup!,
        destination:    _selectedDestination!,
        rideType:       _selectedRideType,
        passengerCount: _selectedRideType == 'Chartered' ? 1 : _passengerCount,
      );
      _showFeedbackDialog(
        isOnline: false,
        message:  'Request sent.\n'
            'Your Pickup ID: $pickupId\n'
            'Listen for your ID when the shuttle arrives.',
      );
    } else {
      _showError(result['error'] ?? 'Failed to send offline request.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.info));
  }

  void _showEsp32Dialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Connect to Campus WiFi'),
        content: const Text(
            'To send an offline request, connect your phone to the '
                '"ASSA-Campus" WiFi hotspot near your hostel, then try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog({required bool isOnline, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(isOnline ? Icons.cloud_done_rounded : Icons.wifi_rounded,
              color: AppColors.success),
          const SizedBox(width: 8),
          Text(isOnline ? 'Request Submitted' : 'Request Sent'),
        ]),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Book a Ride',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: _checkingConnectivity
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Mode banner ──────────────────────────────────────
          _ModeBanner(isOnline: _isOnline),
          const SizedBox(height: 16),

          // ── Pickup ID display ────────────────────────────────
          if (_userData?['pickupId'] != null) ...[
            _PickupIdBadge(pickupId: _userData!['pickupId'] as String),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),

          // ── Bargain notice ───────────────────────────────────
          _BargainNotice(),
          const SizedBox(height: 16),

          // ── Pickup location ──────────────────────────────────
          const Text('Pickup Point',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          if (!_isOnline)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Offline mode: only hostel access points available as pickup',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          _LocationDropdown(
            value:     _selectedPickup,
            locations: _pickupLocations,
            hint:      'Select pickup point',
            onChanged: (v) => setState(() => _selectedPickup = v),
          ),
          const SizedBox(height: 16),

          // ── Drop-off area ─────────────────────────────────────
          const Text('Drop-off Area',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          _LocationDropdown(
            value:     _selectedDestination,
            locations: _destinationLocations,
            hint:      'Select area',
            onChanged: (v) => setState(() => _selectedDestination = v),
          ),
          const SizedBox(height: 16),

          // ── Ride type ────────────────────────────────────────
          const Text('Ride Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(children: ['Shared', 'Chartered'].map((type) {
            final selected = _selectedRideType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedRideType = type;
                  if (type == 'Chartered') _passengerCount = 1;
                }),
                child: Container(
                  margin: EdgeInsets.only(
                      right: type == 'Shared' ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color:   selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border:  Border.all(
                        color: selected ? AppColors.primary : AppColors.inputBorder),
                  ),
                  child: Text(type,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : AppColors.textSecondary)),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),

          // ── Passenger count (Shared only) ────────────────────
          if (_selectedRideType == 'Shared') ...[
            const Text('Number of Passengers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(
                onPressed: _passengerCount > 1
                    ? () => setState(() => _passengerCount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
                color: AppColors.primary,
              ),
              Text('$_passengerCount',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              IconButton(
                onPressed: _passengerCount < 4
                    ? () => setState(() => _passengerCount++)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
                color: AppColors.primary,
              ),
              const Text('(max 4)',
                  style: TextStyle(fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Submit ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text:      _isOnline ? 'Submit Request' : 'Send via Campus WiFi',
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submitRequest,
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Mode Banner ────────────────────────────────────────────────────────────
class _ModeBanner extends StatelessWidget {
  final bool isOnline;
  const _ModeBanner({required this.isOnline});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.successLight
            : AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOnline ? AppColors.success : AppColors.warning,
            width: 1),
      ),
      child: Row(children: [
        Icon(isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: isOnline ? AppColors.success : AppColors.warning,
            size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(
          isOnline
              ? 'Online mode — request goes directly to Firebase'
              : 'Offline mode — request sent via campus WiFi to ESP32 gateway',
          style: TextStyle(
              fontSize: 12,
              color: isOnline ? AppColors.success : AppColors.warning,
              fontWeight: FontWeight.w500),
        )),
      ]),
    );
  }
}

// ── Pickup ID Badge ────────────────────────────────────────────────────────
// Shown on the request screen so users know what ID the driver will call
class _PickupIdBadge extends StatelessWidget {
  final String pickupId;
  const _PickupIdBadge({required this.pickupId});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.3),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.badge_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Pickup ID',
                  style: TextStyle(color: Colors.white70, fontSize: 11,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(pickupId,
                  style: const TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: 4)),
              const Text('Driver will call this ID when your shuttle arrives',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ])),
      ]),
    );
  }
}


// ── Bargain Notice ─────────────────────────────────────────────────────────
class _BargainNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFA000).withOpacity(0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            color: Color(0xFFF57F17), size: 18),
        const SizedBox(width: 10),
        const Expanded(child: Text(
          'Select the drop-off area closest to your destination. '
              'You can bargain with the driver on the exact drop-off point when the shuttle arrives.',
          style: TextStyle(fontSize: 12, color: Color(0xFF5D4037), height: 1.5),
        )),
      ]),
    );
  }
}

// ── Location Dropdown ──────────────────────────────────────────────────────
class _LocationDropdown extends StatelessWidget {
  final String?        value;
  final List<String>   locations;
  final String         hint;
  final ValueChanged<String?> onChanged;
  const _LocationDropdown({
    required this.value,
    required this.locations,
    required this.hint,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:       value,
          hint:        Text(hint,
              style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
          isExpanded:  true,
          icon:        const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          items: locations.map((loc) => DropdownMenuItem(
            value: loc,
            child: Text(loc,
                style: const TextStyle(fontSize: 14,
                    color: AppColors.textPrimary)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}