import 'song_model.dart';
import 'artist_model.dart';

class SearchResponse {
  final List<Song> songs;
  final List<Artist> artists;
  final bool isLoading;

  SearchResponse({
    required this.songs,
    required this.artists,
    this.isLoading = false,
  });

  factory SearchResponse.empty() => SearchResponse(songs: [], artists: [], isLoading: false);

  SearchResponse copyWith({
    List<Song>? songs,
    List<Artist>? artists,
    bool? isLoading,
  }) {
    return SearchResponse(
      songs: songs ?? this.songs,
      artists: artists ?? this.artists,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
