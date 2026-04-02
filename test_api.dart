import 'package:dio/dio.dart';
void main() async {
  final dio = Dio();
  // Fetch some random YouTube Music playlist
  try {
    final response = await dio.post(
      'https://music.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
      data: {
        "context": {
          "client": {
            "clientName": "WEB_REMIX",
            "clientVersion": "1.20230213.01.00",
          }
        },
        "browseId": "VLPL4fGSI1pIOfnZ8tXqSgD2d5w0l1G0Sj7t"
      }
    );
    print('Fetched ${response.data.toString().length} chars');
    
    // Check for continuation
    final nextCont = RegExp(r'"continuation":"([^"]+)"').firstMatch(response.data.toString());
    if (nextCont != null) {
      print('FOUND CONTINUATION: \${nextCont.group(1)}');
      
      final contRes = await dio.post(
        'https://music.youtube.com/youtubei/v1/browse?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
        data: {
          "context": {
            "client": {
              "clientName": "WEB_REMIX",
              "clientVersion": "1.20230213.01.00",
            }
          },
          "continuation": nextCont.group(1)
        }
      );
      print('Continuation response: \${contRes.data.toString().length} chars');
    } else {
      print('NO CONTINUATION FOUND!');
    }
  } catch(e) {
    print('Error: \$e');
  }
}
