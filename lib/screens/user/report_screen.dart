import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ======================================================================
// SUPPORT & COMPLAINTS — Full two-way chat
//
// User can:
//   - Tap a category chip to file a quick complaint (auto-bot reply)
//   - Type free-form messages at any time
//   - See admin replies in real-time (same thread)
//   - See 🔒 badge on private messages from admin
//
// Admin side (admin_chat_screen.dart → _SupportChatViewer):
//   - Sees all messages in this same thread
//   - Can reply as admin or send private messages
//
// Firestore: support_chats/support_{uid}/messages
// ======================================================================

class ReportScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const ReportScreen({super.key, this.userData});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll  = ScrollController();
  bool  _sending = false;

  String get _uid  => FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _name => widget.userData?['name'] ?? 'User';

  static const List<Map<String, String>> _categories = [
    {'icon': '🚌', 'label': 'Shuttle issue'},
    {'icon': '🕐', 'label': 'Late arrival'},
    {'icon': '😤', 'label': 'Rude driver'},
    {'icon': '⚡', 'label': 'Speeding'},
    {'icon': '🔧', 'label': 'Vehicle condition'},
    {'icon': '❓', 'label': 'Other'},
  ];

  static const Map<String, String> _autoReplies = {
    'Shuttle issue':
    'Thanks for reporting the shuttle issue! 🚌 Your complaint has been logged and will be reviewed. If urgent, please include the shuttle ID.',
    'Late arrival':
    "We're sorry your shuttle was late! ⏱️ This has been noted. Include the shuttle ID for faster resolution.",
    'Rude driver':
    'We take driver conduct very seriously. 😔 This report has been escalated. Please add the shuttle ID and any details you remember.',
    'Speeding':
    "Safety is our top priority. ⚠️ This speeding report has been flagged as urgent. We'll review the shuttle's trip data immediately.",
    'Vehicle condition':
    "Thank you for flagging this vehicle concern. 🔧 We'll schedule an inspection. Describe what you noticed to help us act faster.",
    'Other':
    'Thanks for reaching out! 📩 Your message has been received and our support team will respond shortly.',
  };

  static const String _defaultAutoReply =
      'Thanks for your message! 📩 Our support team has received it and will respond as soon as possible.';

  CollectionReference get _messages => FirebaseFirestore.instance
      .collection('support_chats')
      .doc('support_$_uid')
      .collection('messages');

  Future<void> _send({String? categoryLabel}) async {
    final text = (categoryLabel != null
        ? '${_categories.firstWhere((c) => c['label'] == categoryLabel)['icon']} $categoryLabel'
        : _msgCtrl.text)
        .trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    try {
      await _messages.add({
        'senderId':   _uid,
        'senderName': _name,
        'text':       text,
        'isBot':      false,
        'isAdmin':    false,
        'isPrivate':  false,
        'timestamp':  FieldValue.serverTimestamp(),
      });

      // Also log to reports collection for admin visibility
      await FirebaseFirestore.instance.collection('reports').add({
        'userId':    _uid,
        'userName':  _name,
        'message':   text,
        'category':  categoryLabel ?? 'General',
        'status':    'open',
        'chatId':    'support_$_uid',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _msgCtrl.clear();
      _scrollToBottom();

      // Bot auto-reply
      await Future.delayed(const Duration(milliseconds: 900));
      final reply = categoryLabel != null
          ? (_autoReplies[categoryLabel] ?? _defaultAutoReply)
          : _defaultAutoReply;
      await _messages.add({
        'senderId':   'bot',
        'senderName': 'ASSA Support',
        'text':       reply,
        'isBot':      true,
        'isAdmin':    false,
        'isPrivate':  false,
        'timestamp':  FieldValue.serverTimestamp(),
      });
      _scrollToBottom();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FF),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(context),
          Expanded(
            child: Column(children: [
              Expanded(child: _buildMessages()),
              _buildCategoryChips(),
              _buildInputBar(),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1A237E), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 5))
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: const Center(
              child: Text('🛡️', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Support & Complaints',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2)),
                SizedBox(height: 3),
                Row(children: [
                  CircleAvatar(
                      backgroundColor: Color(0xFF69F0AE), radius: 4),
                  SizedBox(width: 5),
                  Text('Chat with admin · Bot active',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ]),
              ]),
        ),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.headset_mic_rounded,
                color: Colors.white70, size: 13),
            SizedBox(width: 4),
            Text('ASSA',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  // ── Messages list ───────────────────────────────────────────────────
  Widget _buildMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: _messages
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1A237E)));
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return _buildEmptyState();

        // Scroll to bottom on new messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });

        final hasAdminReply =
        docs.any((d) => (d.data() as Map)['isAdmin'] == true);
        final hasPrivate =
        docs.any((d) => (d.data() as Map)['isPrivate'] == true);

        return Column(children: [
          // Admin replied banner
          if (hasAdminReply || hasPrivate)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color:
                      const Color(0xFF004D40).withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(children: [
                const Text('✅ ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(
                    hasPrivate
                        ? 'Admin has sent you a private message'
                        : 'Admin has replied to your complaint',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final isMe      = d['senderId']  == _uid;
                final isBot     = d['isBot']     == true;
                final isAdmin   = d['isAdmin']   == true;
                final isPrivate = d['isPrivate'] == true;
                final text      = d['text']      ?? '';
                final ts        = d['timestamp'] as Timestamp?;
                final time = ts != null
                    ? TimeOfDay.fromDateTime(ts.toDate())
                    .format(context)
                    : '';
                return _ChatBubble(
                  text: text,
                  isMe: isMe,
                  isBot: isBot,
                  isAdmin: isAdmin,
                  isPrivate: isPrivate,
                  time: time,
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF1A237E).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: const Center(
              child: Text('🛡️', style: TextStyle(fontSize: 36))),
        ),
        const SizedBox(height: 16),
        const Text('ASSA Support',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 6),
        const Text(
          'Tap a category to file a complaint,\nor type your message — admin will reply here directly.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 10, runSpacing: 10, children: [
          _Pill('⚡ Instant bot reply'),
          _Pill('🔒 Private & secure'),
          _Pill('👨‍💼 Admin replies here'),
          _Pill('📨 Real-time chat'),
        ]),
      ]),
    );
  }

  // ── Category chips ──────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Quick report:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.5)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map((cat) => GestureDetector(
                onTap: () =>
                    _send(categoryLabel: cat['label']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E)
                        .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF1A237E)
                            .withOpacity(0.2)),
                  ),
                  child: Text(
                      '${cat['icon']} ${cat['label']}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E))),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 4),
          ]),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, -2))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Message admin or describe your issue...',
                hintStyle:
                TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : () => _send(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: _sending
                  ? null
                  : const LinearGradient(
                  colors: [
                    Color(0xFF1A237E),
                    Color(0xFF3949AB)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              color: _sending ? Colors.grey.shade300 : null,
              shape: BoxShape.circle,
              boxShadow: _sending
                  ? []
                  : [
                BoxShadow(
                    color: const Color(0xFF1A237E)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3))
              ],
            ),
            child: _sending
                ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ── Chat bubble ─────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final String text, time;
  final bool isMe, isBot, isAdmin, isPrivate;
  const _ChatBubble({
    required this.text,
    required this.isMe,
    required this.isBot,
    required this.isAdmin,
    required this.isPrivate,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final bool showPrivateBadge = isAdmin && isPrivate;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isBot
                      ? [
                    const Color(0xFF1A237E),
                    const Color(0xFF3949AB)
                  ]
                      : isPrivate
                      ? [
                    const Color(0xFFE65100),
                    const Color(0xFFFF6D00)
                  ]
                      : [
                    const Color(0xFF004D40),
                    const Color(0xFF00695C)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                  child: Text(
                    isBot
                        ? '🛡️'
                        : isPrivate
                        ? '🔒'
                        : '👨‍💼',
                    style: const TextStyle(fontSize: 14),
                  )),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      isBot
                          ? 'ASSA Support'
                          : isPrivate
                          ? '🔒 Admin (Private)'
                          : '👨‍💼 Admin',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPrivate
                              ? const Color(0xFFE65100)
                              : isBot
                              ? const Color(0xFF1A237E)
                              : const Color(0xFF004D40)),
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                        colors: [
                          Color(0xFF1A237E),
                          Color(0xFF283593)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                        : isPrivate
                        ? const LinearGradient(
                        colors: [
                          Color(0xFFE65100),
                          Color(0xFFEF6C00)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                        : isAdmin
                        ? const LinearGradient(
                        colors: [
                          Color(0xFF004D40),
                          Color(0xFF00695C)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                        : null,
                    color: (!isMe && !isAdmin && !isPrivate)
                        ? Colors.white
                        : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                      Radius.circular(isMe ? 18 : 4),
                      bottomRight:
                      Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: isMe
                              ? const Color(0xFF1A237E)
                              .withOpacity(0.25)
                              : isPrivate
                              ? const Color(0xFFE65100)
                              .withOpacity(0.25)
                              : isAdmin
                              ? const Color(0xFF004D40)
                              .withOpacity(0.2)
                              : Colors.black
                              .withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: (isMe || isAdmin || isPrivate)
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            height: 1.45),
                      ),
                      if (showPrivateBadge) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius:
                              BorderRadius.circular(8)),
                          child: const Text(
                              '🔒 Private message from admin',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70)),
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                      top: 3, left: 4, right: 4),
                  child: Text(time,
                      style: const TextStyle(
                          fontSize: 9.5, color: Colors.grey)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

Widget _Pill(String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
      color: const Color(0xFF1A237E).withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: const Color(0xFF1A237E).withOpacity(0.15))),
  child: Text(label,
      style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF1A237E),
          fontWeight: FontWeight.w600)),
);