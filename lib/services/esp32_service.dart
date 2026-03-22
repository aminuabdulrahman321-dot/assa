import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// ═══════════════════════════════════════════════════════════════════════════
/// ASSA ESP32 SERVICE  —  Updated Location Set + Pickup ID System
/// Flutter App ↔ ESP32 Access Point ↔ LoRa ↔ Gateway ↔ Firebase
/// ═══════════════════════════════════════════════════════════════════════════
///
/// ── PICKUP ID FORMAT ────────────────────────────────────────────────────────
/// Each registered user gets a random 3-character Pickup ID at registration.
/// Format: 1 uppercase letter  +  2 digits  →  e.g. K47, T83, B12
///
/// Why this format?
///   • 3 ASCII chars = 3 bytes — smallest human-readable identifier possible
///   • 26 × 10 × 10 = 2,600 unique IDs — enough for AFIT's student population
///   • 1 letter prefix makes it visually distinct from numeric codes
///   • Driver can read it aloud easily: "Kay four seven — your ride is here"
///   • Fits 4 IDs per LCD row: "K47 T83 B12 Z91" = 15 chars ✓ (≤20 limit)
///   • Stored in Firestore as users/{uid}.pickupId
///
/// ── LCD DISPLAY  (20×4, PCF8574 I2C — NO scrolling, fixed 20-char rows) ───
///
/// LOCATION CODES (1–12) and their 3-char LCD abbreviations:
///   Code  Full Name                  LCD Abbr  Notes
///   ────  ─────────────────────────  ────────  ────────────────────────────
///     1   AFIT Gates                 AGT       Main campus entrance/exit
///     2   45×1 Hostel                45H       Offline pickup ★
///     3   Old Girls Hostel           OGH       Offline pickup ★
///     4   TETFUND Hostel             TFH       TETFUND residential block
///     5   BK                         BKG       BK area / BK Gate
///     6   Boys Hostel                BYH       Offline pickup ★
///     7   Alfa Hall                  AFH       Alpha Hall lecture complex
///     8   EED                        EED       Electrical/Electronics Dept
///     9   AFIT Mosque                MSQ       Central mosque
///    10   New Mechanical             NME       New Mechanical Dept
///    11   Centre of Entrepreneurship EPC       Entrepreneurship centre
///    12   Hall A                     HLA       Hall A lecture block
///
/// ★ Offline pickup = ESP32 access point installed at that location.
///   Only these 3 are valid as PICKUP in offline mode.
///   All 12 are valid as DESTINATION in both modes.
///
/// ── PACKET FORMAT (15-byte binary over HTTP POST to ESP32) ─────────────────
/// Fixed-width binary — no JSON overhead. Both sides decode by byte position.
/// Airtime at SF10 125kHz: ~280ms vs ~640ms for JSON. 56% reduction.
///
///   Byte  Field     Size  Description
///   ────  ────────  ────  ──────────────────────────────────────────────────
///   B0    magic     1     0xA5 — ASSA packet identifier
///   B1    PID[0]    1     ASCII char 1 of pickupId  e.g. 'K' = 0x4B
///   B2    PID[1]    1     ASCII char 2 of pickupId  e.g. '4' = 0x34
///   B3    PID[2]    1     ASCII char 3 of pickupId  e.g. '7' = 0x37
///   B4    pc        1     Pickup location code 1–12
///   B5    dc        1     Destination code 1–12
///   B6    rt|pax    1     High nibble = rt (0/1), Low nibble = pax (1–4)
///   B7    ap_id     1     Access point ID (1=45x1, 2=OldGirls, 3=Boys)
///   B8    msg_type  1     0x01 = ride request
///   B9    ts[0]     1     Unix timestamp byte 3 (MSB)
///   B10   ts[1]     1     Unix timestamp byte 2
///   B11   ts[2]     1     Unix timestamp byte 1
///   B12   ts[3]     1     Unix timestamp byte 0 (LSB)
///   B13   crc_hi    1     CRC-16/CCITT high byte
///   B14   crc_lo    1     CRC-16/CCITT low byte
///
/// Example: pid=K47, pc=2, dc=7, rt=0, pax=2, ap_id=1
///   A5 4B 34 37 02 07 02 01 01 XX XX XX XX CRC CRC  (15 bytes)
///
/// ── LCD LAYOUT ANALYSIS ─────────────────────────────────────────────────────
///
/// ┌────────────────────┐  ← 20 chars wide
/// │ Row 0: ride type   │
/// │ Row 1: pickup IDs  │
/// │ Row 2: route       │
/// │ Row 3: destination │
/// └────────────────────┘
///
/// CASE A — Multiple passengers, DIFFERENT pickup points, same destination:
///   Row 0: "ASSA - SHARED       "   (20 chars)
///   Row 1: "K47 T83 B12 Z91     "   (pickup IDs, space-separated, max 4 × 4 = 16 chars ✓)
///   Row 2: "45H>OGH>BYH>AGT     "   (pickup abbreviations → with > as separator)
///   Row 3: "TO:  Alfa Hall      "   (destination full name, max ~16 chars)
///
/// CASE B — Multiple passengers, SAME pickup point, same destination:
///   Row 0: "ASSA - SHARED       "
///   Row 1: "K47 T83 B12 Z91     "
///   Row 2: "FROM: 45x1 Hostel   "   (single pickup full name, ≤15 chars after "FROM: ")
///   Row 3: "TO:  EED      [4px] "   (destination + pax count badge, max 20 ✓)
///
/// CASE C — Single passenger or Chartered:
///   Row 0: "ASSA - CHARTERED    "  or  "ASSA - SINGLE       "
///   Row 1: "ID:   K47           "
///   Row 2: "FROM: Boys Hostel   "
///   Row 3: "TO:  AFIT Mosque    "
///
/// ── 20-CHAR VALIDATION ──────────────────────────────────────────────────────
/// "ASSA - SHARED       " = 20 ✓    "ASSA - CHARTERED    " = 20 ✓
/// "K47 T83 B12 Z91     " = 20 ✓    "ID:   K47           " = 20 ✓
/// "45H>OGH>BYH>AGT     " = 20 ✓    "FROM: Boys Hostel   " = 20 ✓
/// "TO:  Alfa Hall      " = 20 ✓    "TO:  EED      [4px] " = 20 ✓
///
class Esp32Service {
  // ── ESP32 Access Point Configuration ──────────────────────────────────
  static const String esp32IpAddress  = '192.168.4.1';
  static const int    esp32Port       = 80;
  static const String requestEndpoint = '/request';
  static const String pingEndpoint    = '/ping';
  static const int    timeoutSeconds  = 10;

  // ── Location Data ──────────────────────────────────────────────────────
  // 12 AFIT campus locations. Codes are 1-based integers (sent in packets).
  // Sorted in a logical on-campus traversal order.

  /// All 12 locations shown in dropdowns (online + offline destinations)
  static const List<String> allLocations = [
    'AFIT Gates',
    '45x1 Hostel',
    'Old Girls Hostel',
    'TETFUND Hostel',
    'BK',
    'Boys Hostel',
    'Alfa Hall',
    'EED',
    'AFIT Mosque',
    'New Mechanical',
    'Centre of Entrepreneurship',
    'Hall A',
  ];

  /// Only these 3 are valid pickup points in offline (ESP32) mode.
  /// ESP32 access points are installed at these hostel locations only.
  static const List<String> offlinePickupLocations = [
    '45x1 Hostel',
    'Old Girls Hostel',
    'Boys Hostel',
  ];

  /// Maps location name → numeric code (1–12) for LoRa packet
  static const Map<String, int> locationCodeMap = {
    'AFIT Gates':                 1,
    '45x1 Hostel':                2,
    'Old Girls Hostel':           3,
    'TETFUND Hostel':             4,
    'BK':                         5,
    'Boys Hostel':                6,
    'Alfa Hall':                  7,
    'EED':                        8,
    'AFIT Mosque':                9,
    'New Mechanical':            10,
    'Centre of Entrepreneurship':11,
    'Hall A':                    12,
  };

  /// Maps location name → 3-char LCD abbreviation (always exactly 3 chars)
  static const Map<String, String> locationAbbrevMap = {
    'AFIT Gates':                 'AGT',
    '45x1 Hostel':                '45H',
    'Old Girls Hostel':           'OGH',
    'TETFUND Hostel':             'TFH',
    'BK':                         'BKG',
    'Boys Hostel':                'BYH',
    'Alfa Hall':                  'AFH',
    'EED':                        'EED',
    'AFIT Mosque':                'MSQ',
    'New Mechanical':             'NME',
    'Centre of Entrepreneurship': 'EPC',
    'Hall A':                     'HLA',
  };

  /// Short display name for LCD Row 2/3 (≤14 chars to fit "FROM: " prefix)
  static const Map<String, String> locationShortName = {
    'AFIT Gates':                 'AFIT Gates',
    '45x1 Hostel':                '45x1 Hostel',
    'Old Girls Hostel':           'Old Girls Hos.',
    'TETFUND Hostel':             'TETFUND Hos.',
    'BK':                         'BK',
    'Boys Hostel':                'Boys Hostel',
    'Alfa Hall':                  'Alfa Hall',
    'EED':                        'EED',
    'AFIT Mosque':                'AFIT Mosque',
    'New Mechanical':             'New Mechanical',
    'Centre of Entrepreneurship': 'Entrepreneur.',
    'Hall A':                     'Hall A',
  };

  // ── Packet Building ────────────────────────────────────────────────────

  /// Builds a 15-byte binary packet for transmission to ESP32 via HTTP POST.
  /// The ESP32 validates the magic byte and CRC before forwarding via LoRa.
  ///
  /// [pickupId]  — user's 3-char pickup ID (e.g. "K47")
  /// [pickup]    — full location name string
  /// [dest]      — full location name string
  /// [rideType]  — 'Shared' or 'Chartered'
  /// [pax]       — 1–4 (only meaningful for Shared)
  /// [apId]      — access point ID (1=45x1, 2=OldGirls, 3=Boys) default 1
  static Uint8List buildPacket({
    required String pickupId,
    required String pickup,
    required String dest,
    required String rideType,
    required int    pax,
    int             apId = 1,
  }) {
    final pc    = locationCodeMap[pickup] ?? 0;
    final dc    = locationCodeMap[dest]   ?? 0;
    final rt    = rideType == 'Chartered' ? 1 : 0;
    final paxC  = (rideType == 'Chartered' ? 1 : pax.clamp(1, 4));
    final rtPax = ((rt & 0x0F) << 4) | (paxC & 0x0F); // bit-pack into one byte

    // Timestamp — seconds since epoch, big-endian uint32
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Build payload bytes (B0–B12, 13 bytes before CRC)
    final buf = Uint8List(15);
    buf[0]  = 0xA5;                          // magic
    buf[1]  = pickupId.isNotEmpty ? pickupId.codeUnitAt(0) : 0x3F; // PID[0]
    buf[2]  = pickupId.length > 1 ? pickupId.codeUnitAt(1) : 0x30; // PID[1]
    buf[3]  = pickupId.length > 2 ? pickupId.codeUnitAt(2) : 0x30; // PID[2]
    buf[4]  = pc;
    buf[5]  = dc;
    buf[6]  = rtPax;
    buf[7]  = apId.clamp(1, 3);
    buf[8]  = 0x01;                          // msg_type: ride request
    buf[9]  = (ts >> 24) & 0xFF;             // timestamp MSB
    buf[10] = (ts >> 16) & 0xFF;
    buf[11] = (ts >>  8) & 0xFF;
    buf[12] =  ts        & 0xFF;             // timestamp LSB

    // CRC-16/CCITT over bytes B0–B12
    final crc = _crc16(buf.sublist(0, 13));
    buf[13] = (crc >> 8) & 0xFF;             // CRC high byte
    buf[14] =  crc       & 0xFF;             // CRC low byte

    return buf;
  }

  /// CRC-16/CCITT (polynomial 0x1021, init 0xFFFF).
  /// Used by ESP32 firmware to validate packets before LoRa TX.
  static int _crc16(Uint8List data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= byte << 8;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }

  // ── LCD Row Helpers ────────────────────────────────────────────────────

  /// Pads or truncates a string to exactly [width] chars for LCD rendering.
  static String lcdPad(String s, [int width = 20]) {
    if (s.length >= width) return s.substring(0, width);
    return s + ' ' * (width - s.length);
  }

  /// Generates the 4 LCD rows for the driver display given a list of
  /// grouped passenger requests (all sharing the same destination).
  ///
  /// [passengers] — list of maps, each with:
  ///   { 'pickupId': 'K47', 'pickup': 'Boys Hostel', 'pax': 1 }
  /// [destination] — full name of shared destination
  /// [rideType]    — 'Shared' or 'Chartered'
  static List<String> buildLcdRows({
    required List<Map<String, dynamic>> passengers,
    required String destination,
    required String rideType,
  }) {
    final totalPax  = passengers.fold<int>(0, (s, p) => s + (p['pax'] as int));
    final destShort = locationShortName[destination] ?? destination;

    // Row 0 — Ride type header
    final String type = rideType == 'Chartered'
        ? (passengers.length == 1 ? 'CHARTERED' : 'SHARED  ')
        : 'SHARED  ';
    final row0 = lcdPad('ASSA - $type');

    // Row 1 — Pickup IDs
    final ids = passengers.map((p) => p['pickupId'] as String).take(4).toList();
    final row1 = lcdPad(ids.join(' '));

    // Row 2 — Route / pickup source
    String row2;
    final pickups = passengers.map((p) => p['pickup'] as String).toSet().toList();
    if (pickups.length == 1) {
      // All from same location
      final shortName = locationShortName[pickups.first] ?? pickups.first;
      row2 = lcdPad('FROM: $shortName');
    } else {
      // Different pickup points → abbreviation chain with > separator
      final abbrevs = pickups
          .take(4)
          .map((l) => locationAbbrevMap[l] ?? l.substring(0, 3).toUpperCase())
          .join('>');
      row2 = lcdPad(abbrevs);
    }

    // Row 3 — Destination + optional pax badge
    final paxBadge = rideType == 'Shared' && totalPax > 1
        ? ' [${totalPax}px]'
        : '';
    final dest3 = 'TO:  $destShort$paxBadge';
    final row3 = lcdPad(dest3);

    return [row0, row1, row2, row3];
  }

  // ── Network ────────────────────────────────────────────────────────────

  /// Checks if the device is connected to the ESP32 WiFi hotspot
  /// by pinging its fixed IP.
  Future<bool> isConnectedToEsp32() async {
    try {
      final socket = await Socket.connect(
        esp32IpAddress, esp32Port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sends a 15-byte binary packet to the ESP32 via HTTP POST.
  /// Content-Type: application/octet-stream — raw bytes, no JSON overhead.
  /// ESP32 validates magic byte (0xA5) + CRC-16 before forwarding via LoRa.
  Future<Map<String, dynamic>> sendRequestToEsp32({
    required String pickupId,
    required String pickupLocation,
    required String destination,
    required String rideType,
    required int    passengerCount,
    int             apId = 1,
  }) async {
    try {
      final packet = buildPacket(
        pickupId: pickupId,
        pickup:   pickupLocation,
        dest:     destination,
        rideType: rideType,
        pax:      passengerCount,
        apId:     apId,
      );

      final client  = HttpClient();
      final request = await client
          .postUrl(Uri.parse(
          'http://$esp32IpAddress:$esp32Port$requestEndpoint'))
          .timeout(Duration(seconds: timeoutSeconds));

      // Raw binary — no JSON, Content-Type: application/octet-stream
      request.headers.set(
          HttpHeaders.contentTypeHeader, 'application/octet-stream');
      request.headers.set(
          HttpHeaders.contentLengthHeader, packet.length.toString());
      request.add(packet);

      final response = await request.close()
          .timeout(Duration(seconds: timeoutSeconds));
      final body     = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        return {'success': true, 'data': body};
      } else {
        return {
          'success': false,
          'error': 'ESP32 returned status ${response.statusCode}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot reach campus hotspot. Connect to the ASSA WiFi first.',
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Move closer to the campus access point.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Offline request failed: $e'};
    }
  }


  // ── Static helpers (used by other screens + firestore_service) ────────────

  /// Maps location name → numeric code (1–12).
  /// Kept as a static method for backward compatibility with all callers.
  static int getLocationCode(String locationName) =>
      locationCodeMap[locationName] ?? 0;

  /// Maps ride type string → numeric code (0=Shared, 1=Chartered).
  static int getRideTypeCode(String rideType) =>
      rideType == 'Chartered' ? 1 : 0;

  /// Maps a numeric status code → human-readable status name.
  /// Used by driver dashboard, my_requests_screen, manage_bookings_screen.
  static const Map<int, String> statusMap = {
    0: 'Pending',
    1: 'Accepted',
    2: 'En Route',
    3: 'Arrived',
    4: 'Completed',
    5: 'Cancelled',
    6: 'Rejected',
  };

  static String getStatusName(int code) => statusMap[code] ?? 'Unknown';

  // ── Legacy helpers kept for backward compatibility ─────────────────────

  static String normalizeNigerianPhone(String phone) {
    String p = phone.trim().replaceAll(' ', '').replaceAll('-', '');
    if (p.startsWith('+234')) return p;
    if (p.startsWith('234'))  return '+$p';
    if (p.startsWith('0'))    return '+234${p.substring(1)}';
    return '+234$p';
  }
}