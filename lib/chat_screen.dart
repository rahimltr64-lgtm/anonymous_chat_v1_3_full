import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

typedef _Doc = QueryDocumentSnapshot<Map<String, dynamic>>;

class ChatScreen extends StatefulWidget {
  final String code;
  const ChatScreen({super.key, required this.code});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _roomStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream;
  String? _uid;
  bool _recorded = false;
  bool _missingHandled = false;
  bool _trimming = false;

  DocumentReference<Map<String, dynamic>> get _roomRef =>
      roomsRef().doc(widget.code);
  CollectionReference<Map<String, dynamic>> get _msgsRef =>
      _roomRef.collection('messages');

  void _initStreams() {
    _roomStream = _roomRef.snapshots();
    _messagesStream = _msgsRef.orderBy('createdAt').snapshots();
  }

  @override
  void initState() {
    super.initState();
    _initStreams();
    ensureUser().then((u) {
      if (mounted) setState(() => _uid = u.uid);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    _snack('تم نسخ الكود: ${widget.code}');
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    try {
      final user = await ensureUser();
      await _msgsRef.add({
        'text': text,
        'senderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        _ctrl.text = text;
        _snack('تعذّر إرسال الرسالة');
      }
    }
  }

  Future<void> _leave() async {
    await RecentRooms.remove(widget.code);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الغرفة'),
        content: const Text('سيتم حذف الغرفة وكل رسائلها نهائيًا لجميع الأعضاء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Pal.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      while (true) {
        final q = await _msgsRef.limit(300).get();
        if (q.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final d in q.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await _roomRef.delete();
      await RecentRooms.remove(widget.code);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _snack('تعذّر حذف الغرفة');
    }
  }

  /// يحذف أقدم الرسائل عند تجاوز الحد الأقصى.
  void _scheduleTrim(List<_Doc> docs) {
    if (_trimming) return;
    _trimming = true;
    final extra = (docs.length - kMaxMessages).clamp(0, 400).toInt();
    final victims = docs.take(extra).map((d) => d.reference).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final r in victims) {
          batch.delete(r);
        }
        await batch.commit();
      } catch (_) {}
      _trimming = false;
    });
  }

  void _messageActions(_Doc d, bool canDelete) {
    final p = Pal.of(context);
    final text = (d.data()['text'] as String?) ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded, color: p.text),
              title: Text('نسخ', style: TextStyle(color: p.text)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await Clipboard.setData(ClipboardData(text: text));
                _snack('تم النسخ');
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Pal.danger),
                title: const Text('حذف', style: TextStyle(color: Pal.danger)),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    await d.reference.delete();
                  } catch (_) {
                    _snack('تعذّر حذف الرسالة');
                  }
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _roomStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _StateView(
            icon: Icons.cloud_off_rounded,
            message: 'حدث خطأ في تحميل الغرفة',
            actionLabel: 'إعادة المحاولة',
            onAction: () => setState(_initStreams),
          );
        }
        if (!snap.hasData) {
          return const AppBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final doc = snap.data!;
        if (!doc.exists) {
          if (!_missingHandled) {
            _missingHandled = true;
            RecentRooms.remove(widget.code);
          }
          return _StateView(
            icon: Icons.search_off_rounded,
            message: 'هذه الغرفة لم تعد موجودة',
            actionLabel: 'رجوع',
            onAction: () => Navigator.of(context).pop(),
          );
        }

        final data = doc.data() ?? <String, dynamic>{};
        final name = ((data['name'] as String?) ?? '').trim();
        final creatorId = data['creatorId'] as String?;
        final isOwner = _uid != null && creatorId == _uid;
        if (!_recorded) {
          _recorded = true;
          RecentRooms.add(widget.code, name);
        }
        return _scaffold(context, name, isOwner);
      },
    );
  }

  Widget _scaffold(BuildContext context, String name, bool isOwner) {
    final p = Pal.of(context);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'غرفة' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.code,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Pal.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'نسخ الكود',
              icon: const Icon(Icons.copy_rounded),
              onPressed: _copyCode,
            ),
            PopupMenuButton<String>(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (v) {
                if (v == 'leave') _leave();
                if (v == 'delete') _deleteRoom();
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: p.text),
                      const SizedBox(width: 10),
                      Text('مغادرة الغرفة', style: TextStyle(color: p.text)),
                    ],
                  ),
                ),
                if (isOwner)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever_rounded,
                            size: 20, color: Pal.danger),
                        SizedBox(width: 10),
                        Text('حذف الغرفة', style: TextStyle(color: Pal.danger)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _messages(context, isOwner)),
            _inputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _messages(BuildContext context, bool isOwner) {
    final p = Pal.of(context);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('حدث خطأ في تحميل الغرفة',
                style: TextStyle(color: p.textDim)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.length > kMaxMessages) _scheduleTrim(docs);
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.border),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 38, color: Pal.accent),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'لا توجد رسائل بعد، ابدأ المحادثة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.textDim, fontSize: 15),
                  ),
                ),
              ],
            ),
          );
        }
        final list = docs.reversed.toList();
        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = list[i];
            final m = d.data();
            final sender = (m['senderId'] as String?) ?? '';
            final text = (m['text'] as String?) ?? '';
            final ts = (m['createdAt'] as Timestamp?)?.toDate();
            final mine = _uid != null && sender == _uid;
            final olderSender = i + 1 < list.length
                ? (list[i + 1].data()['senderId'] as String?) ?? ''
                : null;
            final sameAsOlder = olderSender == sender;
            return _MessageBubble(
              text: text,
              mine: mine,
              alias: aliasFor(sender),
              time: ts,
              showName: !mine && !sameAsOlder,
              topGap: sameAsOlder ? 3 : 12,
              onLongPress: () => _messageActions(d, mine || isOwner),
            );
          },
        );
      },
    );
  }

  Widget _inputBar(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 5,
                maxLength: kMaxMessageLength,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: p.text, fontSize: 15.5),
                decoration: inputDeco(context, hint: 'اكتب رسالة مجهولة...'),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  gradient: Pal.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x551C9BFF),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final Alias alias;
  final DateTime? time;
  final bool showName;
  final double topGap;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.text,
    required this.mine,
    required this.alias,
    required this.time,
    required this.showName,
    required this.topGap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final maxW = MediaQuery.of(context).size.width * 0.78;
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(18),
      topEnd: const Radius.circular(18),
      bottomStart: Radius.circular(mine ? 4 : 18),
      bottomEnd: Radius.circular(mine ? 18 : 4),
    );
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Align(
        alignment:
            mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
              decoration: BoxDecoration(
                gradient: mine ? Pal.gradient : null,
                color: mine ? null : p.bubble,
                borderRadius: radius,
                border: mine ? null : Border.all(color: p.border),
                boxShadow: [
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showName) ...[
                    Text(
                      '${alias.emoji} ${alias.name}',
                      style: TextStyle(
                        color: alias.color,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: mine ? Colors.white : p.text,
                      fontSize: 15.5,
                      height: 1.45,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 3),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        DateFormat('HH:mm').format(time!),
                        style: TextStyle(
                          color: mine ? const Color(0xB3FFFFFF) : p.textDim,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _StateView({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: Pal.accent),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 200,
                  child: GradientButton(
                    label: actionLabel,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: onAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
