class Song {
  final String id;
  final String title;
  final String artist;
  final String? artistId;
  final String duration;
  final String thumbnailUrl;
  final bool isMusic;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.artistId,
    required this.duration,
    required this.thumbnailUrl,
    this.isMusic = true,
  });

  String get musicUrl => 'https://music.youtube.com/watch?v=$id';

  factory Song.fromVideo(dynamic video) {
    // Assuming 'video' is a Video object from youtube_explode_dart
    return Song(
      id: video.id.value,
      title: video.title,
      artist: video.author,
      duration: video.duration?.toString().split('.').first ?? '00:00',
      thumbnailUrl: video.thumbnails.highResUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistId': artistId,
      'duration': duration,
      'thumbnailUrl': thumbnailUrl,
      'isMusic': isMusic,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      artistId: map['artistId'],
      duration: map['duration'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      isMusic: map['isMusic'] ?? true,
    );
  }
}
