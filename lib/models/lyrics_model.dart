class LyricsLine {
  final Duration timestamp;
  final String text;

  LyricsLine({required this.timestamp, required this.text});

  factory LyricsLine.fromMap(Map<String, dynamic> map) {
    return LyricsLine(
      timestamp: Duration(milliseconds: map['startTimeMs'] as int),
      text: map['text'] as String,
    );
  }
}

class LyricsData {
  final List<LyricsLine> lines;
  final String? source;

  LyricsData({required this.lines, this.source});

  bool get isSynced => lines.isNotEmpty && lines.any((l) => l.timestamp != Duration.zero);
}
