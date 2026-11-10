import '../../core/network/api_client.dart';

int videoId(Object? value) {
  if (value is! int || value <= 0) {
    throw const ApiException('Dữ liệu video thiếu mã định danh hợp lệ.');
  }
  return value;
}

String validateVideoUrl(String text) {
  final uri = Uri.tryParse(text.trim());
  final host = uri?.host.toLowerCase() ?? '';
  final supported = [
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'tiktok.com',
  ].any((domain) => host == domain || host.endsWith('.$domain'));
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      !supported ||
      text.length > 2048) {
    throw const ApiException('Hãy nhập liên kết YouTube hoặc TikTok hợp lệ.');
  }
  return uri.toString();
}

class LearningVideo {
  LearningVideo.fromJson(this.data)
    : id = videoId(data['id']),
      platform = jsonText(data, 'platform').toUpperCase(),
      sourceId = jsonText(data, 'videoId'),
      subtitles = jsonObjects(data['subtitles'] ?? []) {
    if (!(platform == 'YOUTUBE' &&
            RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(sourceId) ||
        platform == 'TIKTOK' && RegExp(r'^[0-9]{10,25}$').hasMatch(sourceId))) {
      throw const ApiException('Nguồn phát video từ máy chủ chưa hợp lệ.');
    }
    for (final subtitle in subtitles) {
      videoId(subtitle['id']);
      final start = subtitle['startMs'], end = subtitle['endMs'];
      if (start is! num ||
          end is! num ||
          !start.isFinite ||
          !end.isFinite ||
          start < 0 ||
          end <= start) {
        throw const ApiException(
          'Mốc thời gian phụ đề từ máy chủ không hợp lệ.',
        );
      }
      jsonObjects(subtitle['words'] ?? []);
    }
  }
  final Map<String, dynamic> data;
  final int id;
  final String platform, sourceId;
  final List<Map<String, dynamic>> subtitles;
  int subtitleAt(int milliseconds) => subtitles.indexWhere(
    (s) =>
        milliseconds >= (s['startMs'] as num) &&
        milliseconds < (s['endMs'] as num),
  );
}

class VideoRepository {
  const VideoRepository(this.api);
  final ApiClient api;
  Future<List<Map<String, dynamic>>> presets(String level) async => jsonObjects(
    await api.get(
      '/api/videos/presets',
      query: level == 'ALL' ? null : {'level': level},
      authenticated: true,
    ),
  );
  Future<List<Map<String, dynamic>>> history() async =>
      jsonObjects(await api.get('/api/videos/history', authenticated: true));
  Future<Map<String, dynamic>> usage() async =>
      jsonObject(await api.get('/api/videos/usage', authenticated: true));
  Future<LearningVideo> open(int id, {bool preset = false}) async =>
      LearningVideo.fromJson(
        jsonObject(
          await api.get(
            preset
                ? '/api/videos/presets/${videoId(id)}'
                : '/api/videos/${videoId(id)}',
            authenticated: true,
            timeout: const Duration(seconds: 180),
          ),
        ),
      );
  Future<LearningVideo> analyze(String url) async => LearningVideo.fromJson(
    jsonObject(
      await api.request(
        'POST',
        '/api/videos/analyze',
        authenticated: true,
        timeout: const Duration(seconds: 180),
        body: {'url': validateVideoUrl(url)},
      ),
    ),
  );
  Future<LearningVideo> reanalyze(int id) async => LearningVideo.fromJson(
    jsonObject(
      await api.request(
        'POST',
        '/api/videos/${videoId(id)}/reanalyze',
        authenticated: true,
        timeout: const Duration(seconds: 180),
      ),
    ),
  );
  Future<Map<String, dynamic>> grammar(int subtitle) async => jsonObject(
    await api.request(
      'POST',
      '/api/videos/subtitles/${videoId(subtitle)}/grammar',
      authenticated: true,
      timeout: const Duration(seconds: 120),
    ),
  );
}
