import 'song_model.dart';

class ArtistDetails {
  final List<Song> popularSongs;
  final List<ArtistSection> sections;

  ArtistDetails({required this.popularSongs, required this.sections});
}

class ArtistSection {
  final String title;
  final List<Song> items;

  ArtistSection({required this.title, required this.items});
}
