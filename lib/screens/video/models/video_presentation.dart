import '../../../core/network/api_client.dart';

/// Display metadata only; playback and AI requests stay in VideoRepository.
class VideoPresentation {
  const VideoPresentation(this.data, {this.baseUrl = ''});
  final Map<String, dynamic> data;
  final String baseUrl;
  String get title => jsonText(data, 'title').trim().isEmpty
      ? 'Video tiếng Nhật'
      : jsonText(data, 'title');
  String get platform => jsonText(data, 'platform').toUpperCase();
  String get sourceLabel => switch (platform) {
    'YOUTUBE' => 'YouTube',
    'TIKTOK' => 'TikTok',
    _ => 'Video',
  };
  String get level => RegExp(r'^N[1-5]$').hasMatch(jsonText(data, 'level'))
      ? jsonText(data, 'level')
      : '';
  String get description => jsonText(data, 'description');
  bool get canPreview => platform == 'YOUTUBE'
      ? RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(jsonText(data, 'videoId'))
      : platform == 'TIKTOK' &&
            RegExp(r'^[0-9]{10,25}$').hasMatch(jsonText(data, 'videoId'));

  String? get thumbnail {
    final raw = jsonText(data, 'thumbnailUrl').trim();
    if (raw.isNotEmpty) {
      final parsed = Uri.tryParse(raw);
      final uri = parsed != null && !parsed.hasScheme
          ? Uri.tryParse(baseUrl)?.resolveUri(parsed)
          : parsed;
      if (uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        return uri.toString();
      }
    }
    if (platform == 'YOUTUBE' && canPreview) {
      return 'https://i.ytimg.com/vi/${jsonText(data, 'videoId')}/hqdefault.jpg';
    }
    return null;
  }
}
