class ZmrPlaylist {
  final String id;
  final String title;
  final String thumbnailUrl;
  final int songCount;
  final String owner;

  ZmrPlaylist({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    this.songCount = 0,
    this.owner = 'YouTube Music',
  });

  ZmrPlaylist copyWith({
    String? id,
    String? title,
    String? thumbnailUrl,
    int? songCount,
    String? owner,
  }) {
    return ZmrPlaylist(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      songCount: songCount ?? this.songCount,
      owner: owner ?? this.owner,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'songCount': songCount,
      'owner': owner,
    };
  }

  factory ZmrPlaylist.fromMap(Map<String, dynamic> map) {
    return ZmrPlaylist(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      songCount: map['songCount'] ?? 0,
      owner: map['owner'] ?? '',
    );
  }
}
