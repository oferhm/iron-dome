import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HighScoreEntry {
  final int score;
  final DateTime date;
  final int level;

  HighScoreEntry({required this.score, required this.date, required this.level});

  Map<String, dynamic> toJson() => {
        'score': score,
        'date': date.toIso8601String(),
        'level': level,
      };

  factory HighScoreEntry.fromJson(Map<String, dynamic> json) => HighScoreEntry(
        score: json['score'] as int,
        date: DateTime.parse(json['date'] as String),
        level: (json['level'] as int?) ?? 1,
      );
}

class HighScoreManager {
  static const _key = 'iron_dome_high_scores';
  static const _maxEntries = 10;

  static final HighScoreManager _instance = HighScoreManager._();
  factory HighScoreManager() => _instance;
  HighScoreManager._();

  final ValueNotifier<List<HighScoreEntry>> scoresNotifier = ValueNotifier([]);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        scoresNotifier.value =
            list.map((e) => HighScoreEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      scoresNotifier.value = [];
    }
  }

  Future<bool> submitScore(int score, int level) async {
    final entry = HighScoreEntry(score: score, date: DateTime.now(), level: level);
    final current = List<HighScoreEntry>.from(scoresNotifier.value);
    current.add(entry);
    current.sort((a, b) => b.score.compareTo(a.score));
    if (current.length > _maxEntries) current.removeRange(_maxEntries, current.length);
    scoresNotifier.value = current;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(current.map((e) => e.toJson()).toList()));
    } catch (_) {}

    // Return true if this is a new personal best
    return current.first.score == score && current.first.date == entry.date;
  }

  int get topScore =>
      scoresNotifier.value.isEmpty ? 0 : scoresNotifier.value.first.score;
}
