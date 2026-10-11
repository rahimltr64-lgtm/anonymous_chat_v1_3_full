import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'theme.dart';

// ---------------------------------------------------------------------------
// إعدادات Cloudinary (رفع الصور والفيديوهات) — بدون بطاقة بنكية
// 1) أنشئ حسابًا مجانيًا على cloudinary.com وانسخ Cloud name من لوحة التحكم.
// 2) Settings > Upload > Upload presets > Add upload preset
//    واجعل Signing mode = Unsigned ثم انسخ اسم الـ preset.
// ---------------------------------------------------------------------------
const String kCloudinaryCloudName = 'vfqbsahn';
const String kCloudinaryUploadPreset = 'anonymous_chat';

const int kMaxImageBytes = 10 * 1024 * 1024; // 10MB
const int kMaxVideoBytes = 40 * 1024 * 1024; // 40MB

bool get mediaConfigured =>
    kCloudinaryCloudName.isNotEmpty && kCloudinaryUploadPreset.isNotEmpty;

class MediaException implements Exception {
  final String message;
  const MediaException(this.message);
  @override
  String toString() => message;
}

class UploadedMedia {
  final String url;
  final bool isVideo;
  final int? width;
  final int? height;
  const UploadedMedia({
    required this.url,
    required this.isVideo,
    this.width,
    this.height,
  });
}

Future<UploadedMedia> uploadMedia(File file, {required bool isVideo}) async {
  final size = await file.length();
  if (isVideo && size > kMaxVideoBytes) {
    throw const MediaException('الفيديو كبير جدًا (الحد الأقصى 40 ميغابايت)');
  }
  if (!isVideo && size > kMaxImageBytes) {
    throw const MediaException('الصورة كبيرة جدًا (الحد الأقصى 10 ميغابايت)');
  }
  final kind = isVideo ? 'video' : 'image';
  final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$kCloudinaryCloudName/$kind/upload');
  final req = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = kCloudinaryUploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', file.path));
  final streamed = await req.send().timeout(const Duration(minutes: 6));
  final body = await streamed.stream.bytesToString();
  Map<String, dynamic> json = {};
  try {
    final d = jsonDecode(body);
    if (d is Map<String, dynamic>) json = d;
  } catch (_) {}
  if (streamed.statusCode != 200) {
    final err = json['error'];
    final msg = err is Map ? '${err['message']}' : 'خطأ ${streamed.statusCode}';
    throw MediaException('فشل الرفع: $msg');
  }
  final url = json['secure_url'];
  if (url is! String || url.isEmpty) {
    throw const MediaException('استجابة غير متوقعة من خادم الرفع');
  }
  return UploadedMedia(
    url: url,
    isVideo: isVideo,
    width: json['width'] is int ? json['width'] as int : null,
    height: json['height'] is int ? json['height'] as int : null,
  );
}

String _transform(String url, String t) =>
    url.replaceFirst('/upload/', '/upload/$t/');

/// نسخة مخففة للعرض داخل الفقاعة.
String imagePreviewUrl(String url) => _transform(url, 'w_900,c_limit,q_auto');

/// صورة مصغّرة للفيديو (أول إطار).
String videoPosterUrl(String url) => _transform(url, 'so_0,w_600,c_limit,q_auto')
    .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '.jpg');

// ---------------------------------------------------------------------------
// عرض الوسائط داخل الفقاعة
// ---------------------------------------------------------------------------

class MediaMessage extends StatelessWidget {
  final bool isVideo;
  final String url;
  final int? width;
  final int? height;
  final double maxWidth;

  const MediaMessage({
    super.key,
    required this.isVideo,
    required this.url,
    required this.maxWidth,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final w = width, h = height;
    final double ratio = (w != null && h != null && w > 0 && h > 0)
        ? (w / h).clamp(0.6, 1.8).toDouble()
        : 4 / 3;
    final src = isVideo ? videoPosterUrl(url) : imagePreviewUrl(url);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            isVideo ? VideoViewerPage(url: url) : ImageViewerPage(url: url),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: maxWidth,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  src,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, child, prog) => prog == null
                      ? child
                      : const ColoredBox(
                          color: Color(0x22000000),
                          child: Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        ),
                  errorBuilder: (c, e, s) => ColoredBox(
                    color: const Color(0x33000000),
                    child: Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.broken_image_rounded,
                      color: Colors.white70,
                      size: 40,
                    ),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 34),
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

// ---------------------------------------------------------------------------
// عارض الصور بملء الشاشة
// ---------------------------------------------------------------------------

class ImageViewerPage extends StatelessWidget {
  final String url;
  const ImageViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, prog) => prog == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded,
                color: Colors.white54, size: 56),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// مشغّل الفيديو بملء الشاشة
// ---------------------------------------------------------------------------

class VideoViewerPage extends StatefulWidget {
  final String url;
  const VideoViewerPage({super.key, required this.url});

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final VideoPlayerController _c;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_failed) {
      body = const Text('تعذّر تشغيل الفيديو',
          style: TextStyle(color: Colors.white70, fontSize: 16));
    } else if (!_c.value.isInitialized) {
      body = const CircularProgressIndicator();
    } else {
      body = ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _c,
        builder: (context, v, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio,
              child: GestureDetector(
                onTap: () => v.isPlaying ? _c.pause() : _c.play(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_c),
                    if (!v.isPlaying)
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0x99000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 42),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            VideoProgressIndicator(
              _c,
              allowScrubbing: true,
              padding: const EdgeInsets.all(16),
              colors: const VideoProgressColors(
                playedColor: Pal.accent,
                bufferedColor: Color(0x55FFFFFF),
                backgroundColor: Color(0x22FFFFFF),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(child: body),
    );
  }
}
