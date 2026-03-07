class Song {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String thumbnailUrl;
  final bool isMusic;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.thumbnailUrl,
    this.isMusic = true,
  });

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
}
