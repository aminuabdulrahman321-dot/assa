import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// Converts any Google Drive sharing URL into a direct-loadable image URL.
String _toDirectImageUrl(String url) {
  if (url.isEmpty) return url;
  if (url.contains('drive.google.com')) {
    final m = RegExp(r'(?:/file/d/|[?&]id=)([a-zA-Z0-9_-]+)').firstMatch(url);
    if (m != null) {
      return 'https://lh3.googleusercontent.com/d/${m.group(1)!}';
    }
  }
  return url;
}

/// Opens a URL in the external browser.
Future<void> openAdLink(String url) async {
  if (url.trim().isEmpty) return;
  try {
    String safe = url.trim();
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

class AdOverlayWrapper extends StatefulWidget {
  final Widget child;
  const AdOverlayWrapper({super.key, required this.child});
  @override
  State<AdOverlayWrapper> createState() => _AdOverlayWrapperState();
}

class _AdOverlayWrapperState extends State<AdOverlayWrapper>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  Map<String, dynamic>? _ad;
  List<Map<String, dynamic>> _ads = [];
  int  _adIndex = 0;
  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeInOut);
    _loadAd();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .get();
      if (snap.docs.isEmpty || !mounted) return;

      // All active ads — every user sees every ad in order
      final allAds = snap.docs
          .where((d) => (d.data()['title'] ?? '').toString().trim().isNotEmpty)
          .map((d) => {'_id': d.id, ...d.data()})
          .toList();
      if (allAds.isEmpty || !mounted) return;

      setState(() {
        _ads     = allAds;
        _adIndex = 0;
        _ad      = allAds[0];
        _visible = true;
      });
      _anim.forward();
      _recordImpression(allAds[0]['_id'] as String);
    } catch (_) {}
  }

  Future<void> _recordImpression(String adId) async {
    try {
      // set+merge so field is created even on old docs that lack impressions
      await FirebaseFirestore.instance.collection('ads').doc(adId).set({
        'impressions': FieldValue.increment(1),
        'lastSeen':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _recordTap(String adId) async {
    try {
      await FirebaseFirestore.instance.collection('ads').doc(adId).set({
        'taps':    FieldValue.increment(1),
        'lastTap': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _dismiss() {
    _anim.reverse().then((_) {
      if (!mounted) return;
      final next = _adIndex + 1;
      if (next < _ads.length) {
        setState(() {
          _adIndex = next;
          _ad      = _ads[next];
        });
        _anim.forward();
        _recordImpression(_ads[next]['_id'] as String);
      } else {
        setState(() => _visible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_visible && _ad != null)
        FadeTransition(
          opacity: _fade,
          child: _AdFullScreen(
            ad:       _ad!,
            onDismiss: _dismiss,
            onTap: () {
              final adId    = _ad!['_id'] as String?;
              final linkUrl = (_ad!['linkUrl'] ?? '').toString();
              if (adId != null) _recordTap(adId);
              openAdLink(linkUrl);
            },
          ),
        ),
    ]);
  }
}

class _AdFullScreen extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _AdFullScreen({
    required this.ad,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawImg   = (ad['imageUrl'] ?? '').toString();
    final imageUrl = _toDirectImageUrl(rawImg);
    final title    = (ad['title']   ?? '').toString();
    final body     = (ad['body']    ?? '').toString();
    final linkUrl  = (ad['linkUrl'] ?? '').toString();
    final hasImg   = imageUrl.isNotEmpty;
    final hasLink  = linkUrl.isNotEmpty;

    return Material(
      color: Colors.black,
      child: GestureDetector(
        onTap: hasLink ? onTap : null,
        child: SizedBox.expand(
          child: Stack(children: [

            // Full screen image
            if (hasImg)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
                  placeholder: (_, __) => Container(
                    color: const Color(0xFF1A237E),
                    child: const Center(child: CircularProgressIndicator(
                        color: Colors.white54, strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) => _placeholder(),
                ),
              )
            else
              Positioned.fill(child: _placeholder()),

            // Dark gradient at bottom
            Positioned(
              bottom: 0, left: 0, right: 0, height: 220,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Top bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.campaign_rounded,
                          color: Colors.white54, size: 11),
                      SizedBox(width: 4),
                      Text('ADVERTISEMENT', style: TextStyle(
                          color: Colors.white54, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    ]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text('SKIP', style: TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

            // Bottom text overlay
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w900,
                          color: Colors.white, height: 1.2,
                          shadows: [Shadow(
                              color: Colors.black54, blurRadius: 8)]),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(body, style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      if (hasLink) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    color: Color(0xFF1A237E), size: 14),
                                SizedBox(width: 6),
                                Text('Tap to open', style: TextStyle(
                                    color: Color(0xFF1A237E), fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                              ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1A237E),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.campaign_rounded,
          color: Colors.white.withOpacity(0.25), size: 64),
      const SizedBox(height: 8),
      Text('Advertisement', style: TextStyle(
          color: Colors.white.withOpacity(0.25), fontSize: 13)),
    ])),
  );
}