import 'dart:convert';
import 'dart:math';

import '../../core/network/api_client.dart';

const feedbackCategories = {
  'BUG': 'Báo lỗi chức năng',
  'CONTENT': 'Góp ý nội dung học tập',
  'IMPROVEMENT': 'Đề xuất tính năng',
  'OTHER': 'Góp ý khác',
};

class FeedbackRepository {
  const FeedbackRepository(this.api);
  final ApiClient api;

  Future<Map<String, dynamic>> mine(int page) async => jsonObject(
    await api.get(
      '/api/feedback/tickets/mine',
      authenticated: true,
      query: {'page': '$page'},
    ),
  );

  Future<void> submit({
    required String category,
    required String title,
    required String description,
    List<int>? screenshot,
  }) async {
    title = title.trim();
    description = description.trim();
    if (!feedbackCategories.containsKey(category) ||
        title.length < 5 ||
        title.length > 160 ||
        description.length < 10 ||
        description.length > 4000) {
      throw const ApiException(
        'Vui lòng kiểm tra chủ đề, tiêu đề và nội dung góp ý.',
      );
    }
    final png =
        screenshot != null &&
        screenshot.length >= 8 &&
        screenshot.take(8).join(',') == '137,80,78,71,13,10,26,10';
    final jpg =
        screenshot != null &&
        screenshot.length >= 3 &&
        screenshot[0] == 255 &&
        screenshot[1] == 216 &&
        screenshot[2] == 255;
    if (screenshot != null &&
        ((!png && !jpg) || screenshot.length > 5 * 1024 * 1024)) {
      throw const ApiException(
        'Ảnh minh họa cần là PNG hoặc JPG, tối đa 5 MB.',
      );
    }
    final boundary = 'qtjp-feedback-${Random.secure().nextInt(1 << 32)}';
    final bytes = <int>[];
    for (final field in {
      'category': category,
      'title': title,
      'description': description,
    }.entries) {
      bytes.addAll(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="${field.key}"\r\n\r\n${field.value}\r\n',
        ),
      );
    }
    if (screenshot != null) {
      bytes.addAll(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="screenshot"; filename="screenshot.${png ? 'png' : 'jpg'}"\r\nContent-Type: image/${png ? 'png' : 'jpeg'}\r\n\r\n',
        ),
      );
      bytes.addAll(screenshot);
      bytes.addAll(utf8.encode('\r\n'));
    }
    bytes.addAll(utf8.encode('--$boundary--\r\n'));
    await api.request(
      'POST',
      '/api/feedback/tickets',
      authenticated: true,
      body: ApiBinaryBody(bytes, 'multipart/form-data; boundary=$boundary'),
    );
  }
}
