import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kMaxMessages = 200;
const int kMaxMessageLength = 1000;
const int kCodeLength = 6;
const int kMaxRecent = 10;
const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class RoomException implements Exception {
  final String message;
  const RoomException(this.message);
  @override
  String toString() => message;
}

/// تسجيل دخول مجهول (Firebase Anonymous Auth).
Future<User> ensureUser() async {
  final auth = FirebaseAuth.instance;
  final current = auth.currentUser;
  if (current != null) return current;
  final cred = await auth.signInAnonymously();
  return cred.user!;
}

CollectionReference<Map<String, dynamic>> roomsRef() =>
    FirebaseFirestore.instance.collection('rooms');

String normalizeCode(String input) =>
    input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String _generateCode() {
  final r = Random.secure();
  return List.generate(
    kCodeLength,
    (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
  ).join();
}

/// ينشئ غرفة جديدة ويعيد كودها.
Future<String> createRoom({String name = ''}) async {
  final user = await ensureUser();
  for (var i = 0; i < 6; i++) {
    final code = _generateCode();
    final ref = roomsRef().doc(code);
    final snap = await ref.get();
    if (snap.exists) continue;
    await ref.set({
      'code': code,
      'name': name.trim(),
      'creatorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }
  throw const RoomException('تعذّر إنشاء كود فريد، حاول مرة أخرى');
}

/// يتحقق من وجود الغرفة ويعيد اسمها (قد يكون فارغًا).
Future<String> joinRoom(String code) async {
  await ensureUser();
  final snap = await roomsRef().doc(code).get();
  if (!snap.exists) throw const RoomException('الغرفة غير موجودة');
  final data = snap.data() ?? {};
  return ((data['name'] as String?) ?? '').trim();
}

// ---------------------------------------------------------------------------
// الغرف الأخيرة (محفوظة محليًا)
// ---------------------------------------------------------------------------

class RecentRoom {
  final String code;
  final String name;
  final int ts;
  const RecentRoom({required this.code, required this.name, required this.ts});

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'ts': ts};

  static RecentRoom? fromJson(dynamic j) {
    if (j is! Map) return null;
    final code = j['code'];
    if (code is! String || code.isEmpty) return null;
    final name = j['name'];
    final ts = j['ts'];
    return RecentRoom(
      code: code,
      name: name is String ? name : '',
      ts: ts is int ? ts : 0,
    );
  }
}

class RecentRooms {
  static const String _key = 'recentRooms';

  static Future<List<RecentRoom>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? <String>[];
      final out = <RecentRoom>[];
      for (final s in raw) {
        try {
          final r = RecentRoom.fromJson(jsonDecode(s));
          if (r != null) out.add(r);
        } catch (_) {}
      }
      out.sort((a, b) => b.ts.compareTo(a.ts));
      return out;
    } catch (_) {
      return <RecentRoom>[];
    }
  }

  static Future<void> _save(List<RecentRoom> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _key,
        list.take(kMaxRecent).map((r) => jsonEncode(r.toJson())).toList(),
      );
    } catch (_) {}
  }

  static Future<void> add(String code, String name) async {
    final list = await load();
    list.removeWhere((r) => r.code == code);
    list.insert(
      0,
      RecentRoom(
        code: code,
        name: name,
        ts: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _save(list);
  }

  static Future<void> remove(String code) async {
    final list = await load();
    list.removeWhere((r) => r.code == code);
    await _save(list);
  }
}

// ---------------------------------------------------------------------------
// الأسماء المجهولة (حيوان + رقم) تُشتق ثابتةً من معرّف المستخدم
// ---------------------------------------------------------------------------

class Alias {
  final String name;
  final String emoji;
  final Color color;
  const Alias(this.name, this.emoji, this.color);
}

const List<String> _animalNames = ['أسد', 'نمر', 'بومة', 'صقر', 'ثعلب', 'ذئب'];
const List<String> _animalEmojis = ['🦁', '🐯', '🦉', '🦅', '🦊', '🐺'];
const List<Color> _aliasColors = [
  Color(0xFFFFB74D),
  Color(0xFFFF8A65),
  Color(0xFFBA68C8),
  Color(0xFF4DD0E1),
  Color(0xFFAED581),
  Color(0xFFF06292),
  Color(0xFF7986CB),
  Color(0xFF4DB6AC),
];

Alias aliasFor(String uid) {
  var h = 0;
  for (final c in uid.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final i = h % _animalNames.length;
  final n = (h ~/ 7) % 90 + 10;
  return Alias(
    '${_animalNames[i]} $n',
    _animalEmojis[i],
    _aliasColors[(h ~/ 13) % _aliasColors.length],
  );
}
