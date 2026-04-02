import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../models/song_model.dart';
import '../services/supabase_service.dart';
import '../services/youtube_service.dart';

class DownloadService {
  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36',
    },
  ));
  final SupabaseService _dbService = SupabaseService();
  final YoutubeService _ytService;

  DownloadService(this._ytService);

  /// Downloads a song to the local device storage.
  /// Returns the local file path if successful.
  Future<String?> downloadSongLocally(Song song) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/${song.id}.m4a';
    final file = File(savePath);

    // Check if file already exists
    if (await file.exists()) {
      debugPrint('ZMR [DOWNLOAD]: File already exists at $savePath');
      return savePath;
    }

    try {
      debugPrint('ZMR [DOWNLOAD]: Beginning ultra-stable stream for ${song.title}...');
      _log('Opening secure stream for ${song.title}...');
      
      final result = await _ytService.downloadStream(song.id);
      if (result == null) throw Exception('Direct stream unavailable');

      final output = file.openWrite();
      int downloaded = 0;
      
      await for (final chunk in result.stream) {
        output.add(chunk);
        downloaded += chunk.length;
        if (result.size > 0) {
          _onProgress(song.id, downloaded / result.size);
        }
      }
      
      await output.flush();
      await output.close();
      
      debugPrint('ZMR [DOWNLOAD]: Success! Direct stream completed.');
      _log('Download complete: ${song.title}');
      
      await _dbService.updateOfflineStatus(song.id, true, savePath);
      return savePath;

    } catch (e) {
      debugPrint('ZMR [DOWNLOAD]: High-stability stream failed: $e. Using fallback...');
      _log('Direct stream failed for ${song.title}, trying URL fallback...');
      
      try {
        final url = await _ytService.getDirectStreamUrl(song.id);
        await _dio.download(
          url, 
          savePath,
          onReceiveProgress: (rcv, total) {
            if (total != -1) {
              _onProgress(song.id, rcv / total);
            }
          },
        );
        
        debugPrint('ZMR [DOWNLOAD]: Fallback download successful!');
        _log('Fallback download successful: ${song.title}');
        await _dbService.updateOfflineStatus(song.id, true, savePath);
        return savePath;
      } catch (fallbackError) {
        debugPrint('ZMR [DOWNLOAD] FATAL: All methods failed: $fallbackError');
        _log('FATAL: Download failed for ${song.title}');
        if (await file.exists()) await file.delete();
        return null;
      }
    }
  }

  // Callbacks for logging
  Function(String, double)? onProgressUpdate;
  Function(String)? onLog;

  void _onProgress(String id, double progress) {
    onProgressUpdate?.call(id, progress);
  }

  void _log(String message) {
    onLog?.call(message);
  }

  /// Downloads a song and then uploads it to Google Drive.
  Future<void> downloadSongToDrive(Song song, {String? folderId}) async {
    try {
      // 1. Download the file locally first (Architecture recommendation)
      final localPath = await downloadSongLocally(song);
      if (localPath == null) throw Exception('Failed to download song locally for Drive upload');

      debugPrint('ZMR [DRIVE]: Uploading local file to Google Drive...');
      
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate(
        scopeHint: [drive.DriveApi.driveFileScope],
      );
      
      final authHeaders = await googleUser.authorizationClient.authorizationHeaders([
        drive.DriveApi.driveFileScope,
      ]);
      
      final authenticateClient = _GoogleAuthClient(authHeaders ?? {});
      final driveApi = drive.DriveApi(authenticateClient);
      
      final file = File(localPath);
      
      var driveFile = drive.File()
        ..name = '${song.title} - ${song.artist}.m4a'
        ..mimeType = 'audio/mp4'; 
        
      if (folderId != null && folderId.isNotEmpty) {
        driveFile.parents = [folderId];
      }
        
      final media = drive.Media(file.openRead(), await file.length());
      
      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );
      
      final fileId = result.id;
      if (fileId != null) {
        debugPrint('ZMR [DRIVE]: Uploaded successfully. ID: $fileId. Setting permissions...');
        
        await driveApi.permissions.create(
          drive.Permission()
            ..type = 'anyone'
            ..role = 'reader',
          fileId,
        );
        
        final driveLink = 'https://docs.google.com/uc?export=download&id=$fileId';
        
        // Update Supabase: Now it preferred Drive link for syncing but we also have local path
        // We update the status to DRIVE.
        await _dbService.updateOfflineStatus(song.id, true, driveLink, isDrive: true);
        
        debugPrint('ZMR [DRIVE]: Finished! Drive link attached successfully.');
      }
    } catch (e) {
      debugPrint('ZMR [DRIVE] ERROR: $e');
    }
  }
}

// Helper class required by googleapis to authenticate HTTP requests
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
