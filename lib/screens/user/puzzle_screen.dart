import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:assa/core/constants/app_colors.dart';
import 'package:assa/widgets/common/common_widgets.dart';
import 'package:assa/widgets/common/ad_overlay.dart';

// ======================================================================
// FIRESTORE COLLECTIONS USED
//   puzzle_images/  { imageUrl, title, uploadedAt, isActive, gridSize }
//   puzzle_scores/  { userId, userName, score, moves, timeTaken,
//                     gridSize, weekKey, monthKey, timestamp }
//
// GRID SIZES SUPPORTED
//   3×3 → 8 tiles + 1 blank  (easier)
//   4×4 → 15 tiles + 1 blank (harder)
//
// SCORE FORMULA (same for both sizes, larger grid = more tiles to move
//   → naturally fewer moves possible → higher denominator → lower raw
//   score for same effort, which is correct since 4×4 IS harder)
//   score = (basePuzzlePoints / moves) × (300 / timeTaken)
//   clamped to [1, basePuzzlePoints]
//
// LEADERBOARD
//   Scores stored with gridSize field.
//   Leaderboard shows separate tabs: 3×3 board | 4×4 board | monthly
//   Champion spotlight shown per tab.
//
// LOST & FOUND BONUS
//   When admin issues a ride credit for a returned item, the credit
//   `amount` is set equal to the finder's best puzzle score this week
//   (whichever grid size is highest). This is fetched from puzzle_scores.
// ======================================================================

// ── Grid size options ──────────────────────────────────────────────────
enum PuzzleSize {
  threeX3(3, '3×3', '8 tiles — easier'),
  fourX4(4, '4×4', '15 tiles — harder');

  const PuzzleSize(this.n, this.label, this.desc);
  final int    n;
  final String label;
  final String desc;

  int get tileCount => n * n;
  int get blankCount => 1;
  int get numberedTiles => tileCount - blankCount;
}

// ======================================================================
// PUZZLE SCREEN
// ======================================================================
// Convert any Google Drive share link to a direct-loadable image URL
String _toDirectImageUrl(String url) {
  if (!url.contains('drive.google.com')) return url;
  final fileIdMatch = RegExp(
    r'(?:/file/d/|[?&]id=)([a-zA-Z0-9_-]+)',
  ).firstMatch(url);
  if (fileIdMatch == null) return url;
  final fileId = fileIdMatch.group(1)!;
  return 'https://drive.google.com/uc?export=view&id=' + fileId;
}

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});
  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  static const int basePuzzlePoints = 1000;

  // Selected grid size — user picks before starting
  PuzzleSize _puzzleSize = PuzzleSize.fourX4;

  // Puzzle state
  List<int> _tiles        = [];
  List<int> _initialTiles = []; // saved shuffle — for "Try Again" same arrangement
  int       _moves        = 0;
  int       _seconds      = 0;
  bool      _started      = false;
  bool      _solved       = false;
  bool      _pickerOpen   = true; // show size picker until game starts
  bool      _submitting   = false; // true while saving score to Firestore

  // Timer speed: starts slow (2s ticks) → switches to 1s after first 30s
  // This gives players more time early on
  static const int _slowPhaseSeconds = 30;
  static const int _slowTickInterval = 2; // counts 1 every 2 real seconds

  Timer? _timer;

  // Weekly image from Firestore (keyed by gridSize)
  Map<String, dynamic>? _puzzleImage;
  bool _loadingImage = true;

  String _userName = '';

  // Convenience getters
  int get gridSize  => _puzzleSize.n;
  int get tileCount => _puzzleSize.tileCount;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _initTiles();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Date keys ──────────────────────────────────────────────────────
  static String get _weekKey {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final week   = ((monday.difference(DateTime(monday.year, 1, 1)).inDays +
        DateTime(monday.year, 1, 1).weekday - 1) ~/ 7) + 1;
    return '${monday.year}-W$week';
  }

  static String get _monthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadPuzzleImage(int size) async {
    setState(() => _loadingImage = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('puzzle_images')
          .where('isActive', isEqualTo: true)
          .where('gridSize', isEqualTo: size)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _puzzleImage  = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
          _loadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingImage = false);
    }
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      if (mounted) setState(() => _userName = doc.data()?['name'] ?? 'User');
    } catch (_) {}
  }

  // ── Tile management ────────────────────────────────────────────────
  void _initTiles() {
    _tiles = List.generate(tileCount, (i) => i); // 0=blank, 1..N=numbered
  }

  void _startGame(PuzzleSize size) {
    setState(() {
      _puzzleSize = size;
      _pickerOpen = false;
    });
    _initTiles();
    _loadPuzzleImage(size.n);
    _shuffleTiles();
  }

  void _shuffleTiles() {
    final rng = Random();
    do {
      _tiles.shuffle(rng);
    } while (!_isSolvable(_tiles) || _isSolved(_tiles));
    _timer?.cancel();
    setState(() {
      _initialTiles = List<int>.from(_tiles); // save for retry
      _moves        = 0;
      _seconds      = 0;
      _solved       = false;
      _started      = true;
    });
    _startTimer();
  }

  // Retry with the EXACT same tile arrangement (same puzzle, fresh timer/moves)
  void _retryTiles() {
    if (_initialTiles.isEmpty) { _shuffleTiles(); return; }
    _timer?.cancel();
    setState(() {
      _tiles   = List<int>.from(_initialTiles);
      _moves   = 0;
      _seconds = 0;
      _solved  = false;
      _started = true;
    });
    _startTimer();
  }

  // Adaptive timer: slow for first _slowPhaseSeconds, then normal speed
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: _slowTickInterval), (_) {
      if (!mounted) return;
      final realSeconds = _seconds + _slowTickInterval;
      // Until we hit the slow phase limit, increment by 1 (so 2 real seconds = +1 display)
      // After that, switch to a 1s timer for full speed
      if (_seconds < _slowPhaseSeconds) {
        setState(() => _seconds += 1);
        if (_seconds >= _slowPhaseSeconds) {
          // Switch to real-time 1s ticks
          _timer?.cancel();
          _timer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _seconds++);
          });
        }
      }
    });
  }

  // Solvability check works for both 3×3 and 4×4:
  //   Odd grid (3×3):  inversions must be even
  //   Even grid (4×4): (inversions + blank_row_from_bottom) must be even
  bool _isSolvable(List<int> tiles) {
    int inversions = 0;
    final flat = tiles.where((t) => t != 0).toList();
    for (int i = 0; i < flat.length; i++) {
      for (int j = i + 1; j < flat.length; j++) {
        if (flat[i] > flat[j]) inversions++;
      }
    }
    if (gridSize.isOdd) {
      return inversions.isEven;
    }
    final blankIdx     = tiles.indexOf(0);
    final blankRow     = blankIdx ~/ gridSize;
    final blankFromBot = gridSize - blankRow;
    return (inversions + blankFromBot).isEven;
  }

  bool _isSolved(List<int> tiles) {
    for (int i = 0; i < tileCount - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  void _onTileTap(int tappedIndex) {
    if (!_started || _solved) return;
    final blankIndex = _tiles.indexOf(0);
    if (!_isAdjacent(tappedIndex, blankIndex)) return;
    setState(() {
      _tiles[blankIndex]  = _tiles[tappedIndex];
      _tiles[tappedIndex] = 0;
      _moves++;
    });
    if (_isSolved(_tiles)) {
      _timer?.cancel();
      setState(() => _solved = true);
      Future.delayed(const Duration(milliseconds: 300), _onPuzzleSolved);
    }
  }

  bool _isAdjacent(int a, int b) {
    final aRow = a ~/ gridSize, aCol = a % gridSize;
    final bRow = b ~/ gridSize, bCol = b % gridSize;
    return (aRow == bRow && (aCol - bCol).abs() == 1) ||
        (aCol == bCol && (aRow - bRow).abs() == 1);
  }

  int _calculateScore() {
    if (_moves == 0) return 0;
    const timeBonus = 300.0;
    final score = (basePuzzlePoints / _moves) * (timeBonus / max(_seconds, 1));
    return score.round().clamp(1, basePuzzlePoints);
  }

  // ── On puzzle solved: save best score per (user, gridSize, week) ──
  Future<void> _onPuzzleSolved() async {
    final score = _calculateScore();
    setState(() => _submitting = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _submitting = false); return; }

    try {
      // Doc ID encodes user + grid size + week so 3×3 and 4×4 don't overwrite each other
      final docId   = '${uid}_${gridSize}x${gridSize}_$_weekKey';
      final existing = await FirebaseFirestore.instance
          .collection('puzzle_scores')
          .doc(docId)
          .get();

      if (!existing.exists || (existing.data()?['score'] ?? 0) < score) {
        await FirebaseFirestore.instance
            .collection('puzzle_scores')
            .doc(docId)
            .set({
          'userId':    uid,
          'userName':  _userName,
          'score':     score,
          'moves':     _moves,
          'timeTaken': _seconds,
          'gridSize':  gridSize,       // 3 or 4
          'gridLabel': '${gridSize}x$gridSize',
          'weekKey':   _weekKey,
          'monthKey':  _monthKey,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _submitting = false);
      _showSolvedDialog(score);
    }
  }

  void _showSolvedDialog(int score) {
    showDialog(
      context:            context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text('${_puzzleSize.label} Solved!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            _ScoreStat('Score', '$score pts',     Icons.star_rounded,      Colors.amber),
            const SizedBox(height: 8),
            _ScoreStat('Moves', '$_moves',        Icons.touch_app_rounded, AppColors.primary),
            const SizedBox(height: 8),
            _ScoreStat('Time',  _fmt(_seconds),   Icons.timer_rounded,     AppColors.success),
            const SizedBox(height: 24),
            const Text('Your score has been saved to the leaderboard!',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            CustomButton(text: 'View Leaderboard', onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
            }),
            const SizedBox(height: 8),
            // Try same puzzle faster (exact same arrangement)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _retryTiles();
                },
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Try Same Puzzle Faster'),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _shuffleTiles();
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.success),
                    foregroundColor: AppColors.success),
                child: const Text('New Shuffle'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _pickerOpen = true);
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.textSecondary)),
                child: const Text('Change Size'),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  String _fmt(int secs) {
    final m = secs ~/ 60, s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ======================================================================
  // BUILD
  // ======================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdOverlayWrapper(child: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _pickerOpen
                  ? _buildSizePicker()
                  : Column(children: [
                _buildStatsBar(),
                const SizedBox(height: 16),
                _buildImagePreview(),
                const SizedBox(height: 16),
                _buildPuzzleGrid(),
                const SizedBox(height: 20),
                if (_started && !_solved)
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _shuffleTiles,
                      icon:  const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Restart'),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => setState(() => _pickerOpen = true),
                      icon:  const Icon(Icons.grid_4x4_rounded, size: 18),
                      label: const Text('Change Size'),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.textSecondary),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                    )),
                  ]),
                const SizedBox(height: 20),
                _buildHowToPlay(),
              ]),
            ),
          ),
        ]),
      )),
    );
  }

  // ── Size picker — shown before and between games ───────────────────
  Widget _buildSizePicker() {
    return Column(children: [
      const SizedBox(height: 20),
      const Text('Choose Grid Size',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('Both sizes share the same score formula.\n4×4 is harder — but earns the same max points!',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary,
              height: 1.5),
          textAlign: TextAlign.center),
      const SizedBox(height: 32),
      ...PuzzleSize.values.map((size) {
        final isSelected = _puzzleSize == size;
        final color = size == PuzzleSize.fourX4
            ? AppColors.primary : const Color(0xFF00897B);
        return GestureDetector(
          onTap: () => setState(() => _puzzleSize = size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:        isSelected ? color : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isSelected ? color : AppColors.cardBorder,
                  width: isSelected ? 2 : 1),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.25),
                  blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: AppColors.shadow,
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(size.label,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : color)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(size.label,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.textPrimary)),
                    Text(size.desc,
                        style: TextStyle(fontSize: 13,
                            color: isSelected ? Colors.white70 : AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Text(
                      size == PuzzleSize.fourX4
                          ? '• ${size.numberedTiles} tiles to arrange\n• Max ${basePuzzlePoints} pts'
                          : '• ${size.numberedTiles} tiles to arrange\n• Max ${basePuzzlePoints} pts',
                      style: TextStyle(fontSize: 11,
                          color: isSelected ? Colors.white60 : AppColors.textHint,
                          height: 1.5),
                    ),
                  ])),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 28),
            ]),
          ),
        );
      }),
      const SizedBox(height: 8),
      CustomButton(
        text:            'Start ${_puzzleSize.label} Puzzle',
        onPressed:       () => _startGame(_puzzleSize),
        icon:            Icons.play_arrow_rounded,
        backgroundColor: _puzzleSize == PuzzleSize.fourX4
            ? AppColors.primary : const Color(0xFF00897B),
      ),
      const SizedBox(height: 20),
      _buildHowToPlay(),
    ]);
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)]),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AFIT Building Puzzle',
                  style: TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w700)),
              Text(
                _pickerOpen
                    ? 'Choose your grid size'
                    : '${_puzzleSize.label} — ${_puzzleSize.numberedTiles} tiles',
                style: const TextStyle(color: Color(0xAAFFFFFF), fontSize: 12),
              ),
            ])),
        IconButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          icon: const Icon(Icons.leaderboard_rounded, color: Colors.white),
          tooltip: 'Leaderboard',
        ),
      ]),
    );
  }

  Widget _buildStatsBar() {
    final color = _puzzleSize == PuzzleSize.fourX4
        ? AppColors.primary : const Color(0xFF00897B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _StatChip(Icons.grid_4x4_rounded,  'Grid',
            _puzzleSize.label, color),
        Container(width: 1, height: 36, color: AppColors.divider),
        _StatChip(Icons.touch_app_rounded, 'Moves',
            '$_moves',         AppColors.primary),
        Container(width: 1, height: 36, color: AppColors.divider),
        _StatChip(Icons.timer_rounded,     'Time',
            _fmt(_seconds),    AppColors.success),
        Container(width: 1, height: 36, color: AppColors.divider),
        _StatChip(Icons.star_rounded,      'Score',
            '${_calculateScore()}',
            _started ? Colors.amber : AppColors.textHint),
      ]),
    );
  }

  Widget _buildImagePreview() {
    if (_loadingImage) {
      return const SizedBox(height: 64,
          child: Center(child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2)));
    }
    if (_puzzleImage == null) {
      return Container(
        padding:    const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.warningLight,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.image_not_supported_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
              'No puzzle image for ${_puzzleSize.label} this week. '
                  'Admin will upload one soon!',
              style: const TextStyle(fontSize: 12, color: AppColors.warning))),
        ]),
      );
    }
    final title  = _puzzleImage!['title'] ?? 'Weekly Puzzle';
    final imgUrl = _puzzleImage!['imageUrl'] as String? ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.25),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Thumbnail preview
        ClipRRect(
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
          child: imgUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: _toDirectImageUrl(imgUrl), width: 72, height: 72, fit: BoxFit.cover,
            placeholder: (_, __) => Container(width: 72, height: 72,
                color: Colors.white12,
                child: const Icon(Icons.image_rounded,
                    color: Colors.white54, size: 28)),
            errorWidget: (_, __, ___) => Container(width: 72, height: 72,
                color: Colors.white12,
                child: const Icon(Icons.broken_image_rounded,
                    color: Colors.white54, size: 28)),
          )
              : Container(width: 72, height: 72, color: Colors.white12,
              child: const Icon(Icons.image_search_rounded,
                  color: Colors.white54, size: 28)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('THIS WEEK · ${_puzzleSize.label.toUpperCase()}',
                style: const TextStyle(fontSize: 9, color: Colors.white60,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Slide tiles to arrange the image!',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
        )),
        const Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(Icons.grid_view_rounded, color: Colors.white60, size: 22),
        ),
      ]),
    );
  }

  Widget _buildTileWidget(int tileVal, double tileSize, double fontSize) {
    final imgUrl = _puzzleImage?['imageUrl'] as String?;
    final n = gridSize;
    // tileVal is 1-based; position in solved state = tileVal-1
    final solvedPos = tileVal - 1;
    final srcRow = solvedPos ~/ n;
    final srcCol = solvedPos  % n;

    if (imgUrl != null && imgUrl.isNotEmpty) {
      // Clip to show only the correct slice of the image
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(children: [
          // Image slice via alignment trick
          SizedBox(
            width: tileSize, height: tileSize,
            child: OverflowBox(
              maxWidth: tileSize * n,
              maxHeight: tileSize * n,
              alignment: Alignment(
                n == 1 ? 0 : -1 + srcCol * 2 / (n - 1),
                n == 1 ? 0 : -1 + srcRow * 2 / (n - 1),
              ),
              child: CachedNetworkImage(
                imageUrl: _toDirectImageUrl(imgUrl),
                width: tileSize * n,
                height: tileSize * n,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.primary,
                  child: Center(child: Text('$tileVal',
                      style: TextStyle(color: Colors.white,
                          fontSize: fontSize, fontWeight: FontWeight.w800))),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary,
                  child: Center(child: Text('$tileVal',
                      style: TextStyle(color: Colors.white,
                          fontSize: fontSize, fontWeight: FontWeight.w800))),
                ),
              ),
            ),
          ),
          // Subtle border overlay
          Container(
            width: tileSize, height: tileSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
                  blurRadius: 4, offset: const Offset(1, 2))],
            ),
          ),
        ]),
      );
    }

    // Fallback: colored numbered tile
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3),
            blurRadius: 4, offset: const Offset(1, 2))],
      ),
      child: Center(child: Text('$tileVal',
          style: TextStyle(color: Colors.white,
              fontSize: fontSize, fontWeight: FontWeight.w800))),
    );
  }

  Widget _buildPuzzleGrid() {
    final screenW  = MediaQuery.of(context).size.width - 32;
    // 3×3 gets a bit more vertical space than 4×4 needs
    final size     = screenW;
    final tileSize = size / gridSize;
    final fontSize = gridSize == 3 ? 28.0 : 18.0;

    return SizedBox(
      width: size, height: size,
      child: Stack(children: [
        // Background board
        Container(
          decoration: BoxDecoration(
            color:        const Color(0xFF1A237E),
            borderRadius: BorderRadius.circular(12),
            border:       Border.all(color: const Color(0xFF0D1B6E), width: 2),
          ),
        ),
        // Tiles
        ..._tiles.asMap().entries.map((entry) {
          final gridIdx = entry.key;
          final tileVal = entry.value;
          if (tileVal == 0) return const SizedBox.shrink();
          final row = gridIdx ~/ gridSize;
          final col = gridIdx  % gridSize;
          return AnimatedPositioned(
            duration: const Duration(milliseconds: 110),
            left:   col * tileSize + 2,
            top:    row * tileSize + 2,
            width:  tileSize - 4,
            height: tileSize - 4,
            child: GestureDetector(
              // Swipe gesture: detect direction and move tile if it can slide
              onPanEnd: (details) {
                final v  = details.velocity.pixelsPerSecond;
                final dx = v.dx.abs();
                final dy = v.dy.abs();
                // Require minimum velocity to count as intentional swipe
                if (dx < 50 && dy < 50) return;
                final blankIndex = _tiles.indexOf(0);
                final blankRow   = blankIndex ~/ gridSize;
                final blankCol   = blankIndex % gridSize;
                final tileRow    = gridIdx ~/ gridSize;
                final tileCol    = gridIdx  % gridSize;
                // Only same row/col neighbours can slide
                if (tileRow != blankRow && tileCol != blankCol) return;
                bool validSwipe = false;
                if (dx > dy) {
                  // Horizontal swipe
                  if (v.dx > 0 && tileRow == blankRow && tileCol == blankCol - 1) validSwipe = true; // swipe right → tile left of blank
                  if (v.dx < 0 && tileRow == blankRow && tileCol == blankCol + 1) validSwipe = true; // swipe left → tile right of blank
                } else {
                  // Vertical swipe
                  if (v.dy > 0 && tileCol == blankCol && tileRow == blankRow - 1) validSwipe = true; // swipe down → tile above blank
                  if (v.dy < 0 && tileCol == blankCol && tileRow == blankRow + 1) validSwipe = true; // swipe up → tile below blank
                }
                if (validSwipe) _onTileTap(gridIdx);
              },
              // Also keep tap for accessibility
              onTap: () => _onTileTap(gridIdx),
              child: _buildTileWidget(tileVal, tileSize - 4, fontSize),
            ),
          );
        }),
        // Solved overlay
        if (_solved)
          Container(
            decoration: BoxDecoration(
              color:        Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 64),
                const SizedBox(height: 8),
                Text('${_puzzleSize.label} SOLVED!',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 26, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildHowToPlay() {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('How to Play',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          '• Swipe a tile toward the blank space to slide it\n'
              '• 3×3: arrange tiles 1–8, blank bottom-right\n'
              '• 4×4: arrange tiles 1–15, blank bottom-right\n'
              '• Fewer moves + faster time = higher score\n'
              '• Score = (1000 ÷ moves) × (300 ÷ seconds)',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary,
              height: 1.6),
        ),
      ]),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────

Widget _ScoreStat(String label, String value, IconData icon, Color color) {
  return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, color: color, size: 18),
    const SizedBox(width: 6),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10,
          color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: 16,
          fontWeight: FontWeight.w800, color: color)),
    ]),
  ]);
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  final Color    color;
  const _StatChip(this.icon, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13,
          fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 9,
          color: AppColors.textSecondary)),
    ]);
  }
}

// ======================================================================
// LEADERBOARD SCREEN
// 3 tabs: 3×3 weekly | 4×4 weekly | Monthly (all sizes merged, best score)
// ======================================================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static String get _weekKey {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final week   = ((monday.difference(DateTime(monday.year, 1, 1)).inDays +
        DateTime(monday.year, 1, 1).weekday - 1) ~/ 7) + 1;
    return '${monday.year}-W$week';
  }

  static String get _monthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AdOverlayWrapper(child: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Container(
            color: const Color(0xFF4A148C),
            child: TabBar(
              controller:           _tab,
              indicatorColor:       Colors.white,
              labelColor:           Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: '3×3 Weekly'),
                Tab(text: '4×4 Weekly'),
                Tab(text: 'Monthly'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildBoard(
                  periodKey:  _weekKey,
                  periodField: 'weekKey',
                  myUid:      myUid,
                  gridSize:   3,
                  label:      '3×3',
                ),
                _buildBoard(
                  periodKey:  _weekKey,
                  periodField: 'weekKey',
                  myUid:      myUid,
                  gridSize:   4,
                  label:      '4×4',
                ),
                _buildMonthlyBoard(myUid),
              ],
            ),
          ),
        ]),
      )),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)]),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
        const Expanded(child: Text('Leaderboard',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w700))),
        const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
      ]),
    );
  }

  // ── Per-grid-size weekly board ────────────────────────────────────────
  Widget _buildBoard({
    required String periodKey,
    required String periodField,
    required String myUid,
    required int    gridSize,
    required String label,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('puzzle_scores')
          .where(periodField, isEqualTo: periodKey)
          .where('gridSize', isEqualTo: gridSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: Color(0xFF6A1B9A)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.leaderboard_rounded, size: 60,
                color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No $label scores this week',
                style: const TextStyle(fontSize: 15,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            const Text('Solve the puzzle to get on the board!',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
          ]));
        }
        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) =>
              ((b.data() as Map)['score'] ?? 0)
                  .compareTo((a.data() as Map)['score'] ?? 0));
        final champ    = docs.first.data() as Map<String, dynamic>;
        final isMyChamp = champ['userId'] == myUid;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildChampionCard(champ, isMyChamp, label),
            const SizedBox(height: 16),
            ...docs.asMap().entries.map((e) {
              final data = e.value.data() as Map<String, dynamic>;
              return _buildRankRow(e.key + 1, data, data['userId'] == myUid);
            }),
          ],
        );
      },
    );
  }

  // ── Monthly board — best score per user regardless of grid size ──────
  Widget _buildMonthlyBoard(String myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('puzzle_scores')
          .where('monthKey', isEqualTo: _monthKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: Color(0xFF6A1B9A)));
        }
        final allDocs = snapshot.data?.docs ?? [];
        if (allDocs.isEmpty) {
          return const Center(child: Text('No scores this month',
              style: TextStyle(color: AppColors.textSecondary)));
        }
        // Deduplicate: best score per user (across all grid sizes)
        final Map<String, Map<String, dynamic>> best = {};
        for (final doc in allDocs) {
          final d   = doc.data() as Map<String, dynamic>;
          final uid = d['userId'] ?? '';
          if (!best.containsKey(uid) ||
              (d['score'] ?? 0) > (best[uid]!['score'] ?? 0)) {
            best[uid] = d;
          }
        }
        final sorted = best.values.toList()
          ..sort((a, b) =>
              (b['score'] ?? 0).compareTo(a['score'] ?? 0));
        final champ    = sorted.first;
        final isMyChamp = champ['userId'] == myUid;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildChampionCard(champ, isMyChamp, champ['gridLabel'] ?? ''),
            const SizedBox(height: 16),
            ...sorted.asMap().entries.map((e) =>
                _buildRankRow(e.key + 1, e.value,
                    e.value['userId'] == myUid)),
          ],
        );
      },
    );
  }

  Widget _buildChampionCard(
      Map<String, dynamic> data, bool isMe, String sizeLabel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.emoji_events_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text('$sizeLabel CHAMPION',
              style: const TextStyle(color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('YOU!', style: TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        Text(data['userName'] ?? 'Unknown',
            style: const TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ChampStat('Score', '${data['score'] ?? 0} pts'),
          const SizedBox(width: 20),
          _ChampStat('Moves', '${data['moves'] ?? 0}'),
          const SizedBox(width: 20),
          _ChampStat('Time',  _fmtS(data['timeTaken'] ?? 0)),
        ]),
      ]),
    );
  }

  Widget _buildRankRow(int rank, Map<String, dynamic> data, bool isMe) {
    final score     = data['score']     ?? 0;
    final gridLabel = data['gridLabel'] ?? '';
    final medal     = rank == 1 ? '🥇' : rank == 2 ? '🥈'
        : rank == 3 ? '🥉' : '#$rank';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF6A1B9A).withOpacity(0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isMe
                ? const Color(0xFF6A1B9A).withOpacity(0.3)
                : AppColors.cardBorder),
      ),
      child: Row(children: [
        SizedBox(width: 36,
            child: Text(medal, style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(data['userName'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis)),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: const Color(0xFF6A1B9A),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('YOU', style: TextStyle(color: Colors.white,
                        fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
                if (gridLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(gridLabel, style: const TextStyle(fontSize: 9,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              Text('${data['moves'] ?? 0} moves · ${_fmtS(data['timeTaken'] ?? 0)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
        Text('$score pts',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: Color(0xFF6A1B9A))),
      ]),
    );
  }

  String _fmtS(int secs) {
    final m = secs ~/ 60, s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

Widget _ChampStat(String label, String value) {
  return Column(children: [
    Text(value, style: const TextStyle(color: Colors.white,
        fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);
}