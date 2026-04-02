class Artist {
  final String id;
  final String name;
  final String thumbnailUrl;

  Artist({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
  });

  factory Artist.fromMap(Map<String, dynamic> map) {
    return Artist(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Artist',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}
