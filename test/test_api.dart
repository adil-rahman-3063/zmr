import 'package:flutter/cupertino.dart';
import 'package:zmr/services/youtube_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final yt = YoutubeService();
  try {
    print('Tokens...');
    await yt.fetchTokens();
    print('Fetching liked songs or PL4fGSI1pIOfnZ8tXqSgD2d5w0l1G0Sj7t...');
    final songs = await yt.fetchPlaylistSongs('VLPL4fGSI1pIOfnZ8tXqSgD2d5w0l1G0Sj7t');
    print('TOTAL SONGS FETCHED: \${songs.length}');
  } catch (e) {
    print('Error: \$e');
  }
}
