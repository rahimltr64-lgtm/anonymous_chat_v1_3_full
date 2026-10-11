import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'chat_screen.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  List<RecentRoom> _recent = <RecentRoom>[];
  bool _creating = false;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final list = await RecentRooms.load();
    if (mounted) setState(() => _recent = list);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _open(String code) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatScreen(code: code)),
    );
    if (mounted) _loadRecent();
  }

  Future<void> _create() async {
    if (_creating) return;
    FocusScope.of(context).unfocus();
    setState(() => _creating = true);
    try {
      final name = _nameCtrl.text.trim();
      final code = await createRoom(name: name);
      await RecentRooms.add(code, name);
      _nameCtrl.clear();
      if (!mounted) return;
      await _open(code);
    } on RoomException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('حدث خطأ، تحقق من الاتصال وحاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join([String? presetCode]) async {
    if (_joining) return;
    final code = normalizeCode(presetCode ?? _codeCtrl.text);
    if (code.isEmpty) {
      _snack('أدخل كود الغرفة أولًا');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _joining = true);
    try {
      final name = await joinRoom(code);
      await RecentRooms.add(code, name);
      _codeCtrl.clear();
      if (!mounted) return;
      await _open(code);
    } on RoomException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('حدث خطأ، تحقق من الاتصال وحاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = normalizeCode(data?.text ?? '');
    if (text.isNotEmpty) {
      setState(() => _codeCtrl.text = text);
    }
  }

  String _when(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'اليوم ${DateFormat('HH:mm').format(d)}';
    if (diff == 1) return 'أمس';
    return DateFormat('d/M/y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Row(
                children: [
                  const Spacer(),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, mode, _) => IconButton(
                      tooltip: 'تبديل الثيم',
                      onPressed: toggleThemeMode,
                      icon: Icon(
                        mode == ThemeMode.dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: p.textDim,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x661C9BFF),
                        blurRadius: 34,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'دردشة مجهولة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'دردشة مجهولة بين الأصدقاء.\nأنشئ غرفة وشارك الكود فقط.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textDim, fontSize: 14.5, height: 1.6),
              ),
              const SizedBox(height: 26),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardTitle(
                      icon: Icons.add_comment_rounded,
                      title: 'إنشاء غرفة جديدة',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameCtrl,
                      maxLength: 30,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                      style: TextStyle(color: p.text),
                      decoration: inputDeco(
                        context,
                        label: 'اسم الغرفة (اختياري)',
                        icon: Icons.edit_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      label: 'إنشاء غرفة جديدة',
                      icon: Icons.bolt_rounded,
                      loading: _creating,
                      onPressed: _create,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardTitle(
                      icon: Icons.login_rounded,
                      title: 'انضمام للغرفة',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeCtrl,
                      maxLength: 12,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _join(),
                      style: TextStyle(
                        color: p.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                      decoration: inputDeco(
                        context,
                        label: 'كود الغرفة',
                        icon: Icons.tag_rounded,
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: 'لصق',
                          onPressed: _pasteCode,
                          icon: Icon(Icons.content_paste_rounded,
                              size: 20, color: p.textDim),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      label: 'انضمام للغرفة',
                      icon: Icons.meeting_room_rounded,
                      loading: _joining,
                      onPressed: _join,
                    ),
                  ],
                ),
              ),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'غرفك الأخيرة',
                    style: TextStyle(
                      color: p.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final r in _recent) _recentTile(context, r),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentTile(BuildContext context, RecentRoom r) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _join(r.code),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: Pal.gradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.forum_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name.isEmpty ? 'غرفة' : r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            r.code,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: Pal.accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          if (_when(r.ts).isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(
                              _when(r.ts),
                              style: TextStyle(color: p.textDim, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إزالة',
                  icon: Icon(Icons.close_rounded, color: p.textDim, size: 20),
                  onPressed: () async {
                    await RecentRooms.remove(r.code);
                    _loadRecent();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _CardTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: Pal.accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: p.text,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
