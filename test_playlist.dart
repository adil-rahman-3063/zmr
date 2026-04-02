import 'lib/services/youtube_service.dart';
import 'lib/services/innertube_client.dart';
void main() async {
  final yt = YoutubeService();
  try {
    // A long public playlist ID (e.g. YouTube's Top 100 Music Videos or another one)
    final songs = await yt.fetchPlaylistSongs('PL4fGSI1pIOfnZ8tXqSgD2d5w0l1G0Sj7t'); // Typical 200+ len playlist
    print('Total songs fetched: \${songs.length}');
  } catch (e) {
    print('Err: \$e');
  }
}
