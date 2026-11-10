import '../../core/navigation/app_routes.dart';
import '../../core/network/api_client.dart';

class AssistantTurn {
  const AssistantTurn(this.role, this.content);
  final String role, content;
  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AssistantLink {
  AssistantLink.fromJson(Map<String, dynamic> data)
    : title = jsonText(data, 'title'),
      path = jsonText(data, 'path'),
      description = jsonText(data, 'description');
  final String title, path, description;
  String? get route => assistantMobileRoute(path);
}

class AssistantReply {
  AssistantReply.fromJson(Map<String, dynamic> data)
    : answer = jsonText(data, 'answer'),
      mode = jsonText(data, 'mode'),
      remaining = (data['remaining'] as num?)?.toInt(),
      links = jsonObjects(data['links'] ?? [])
          .map(AssistantLink.fromJson)
          .toList(growable: false),
      sources = jsonObjects(data['sources'] ?? []) {
    if (answer.trim().isEmpty) {
      throw const ApiException('Kyuto chưa trả lời được. Vui lòng thử lại.');
    }
  }
  final String answer, mode;
  final int? remaining;
  final List<AssistantLink> links;
  final List<Map<String, dynamic>> sources;
}

class AssistantRepository {
  const AssistantRepository(this.api);
  final ApiClient api;

  Future<AssistantReply> send(
    String message,
    List<AssistantTurn> history,
  ) async {
    final text = message.trim();
    if (text.isEmpty || text.length > 1000) {
      throw const ApiException('Câu hỏi cần có từ 1 đến 1.000 ký tự.');
    }
    final valid = history
        .where(
          (turn) =>
              ['user', 'assistant'].contains(turn.role) &&
              turn.content.trim().isNotEmpty,
        )
        .toList();
    return AssistantReply.fromJson(
      jsonObject(
        await api.request(
          'POST',
          '/api/assistant/chat',
          authenticated: true,
          timeout: const Duration(seconds: 120),
          body: {
            'message': text,
            'history': valid
                .skip(valid.length > 10 ? valid.length - 10 : 0)
                .map((turn) => turn.toJson())
                .toList(),
          },
        ),
      ),
    );
  }
}

/// Only declared native routes are accepted, never an AI-provided external URL.
String? assistantMobileRoute(String path) {
  if (path.length > 1200) return null;
  final uri = Uri.tryParse(path);
  String decoded;
  try {
    decoded = Uri.decodeFull(path);
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
  if (uri == null ||
      !path.startsWith('/') ||
      path.startsWith('//') ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasFragment ||
      path.contains('\\') ||
      decoded.contains('..')) {
    return null;
  }
  final level = uri.queryParameters['level'] ?? 'N5';
  if (!RegExp(r'^N[1-5]$').hasMatch(level)) return null;
  switch (uri.path) {
    case '/':
      return uri.hasQuery ? null : '/';
    case '/profile':
      return uri.hasQuery ? null : AppRoutes.profile;
    case '/vip':
      return uri.hasQuery ? null : AppRoutes.vip;
    case '/dictionary':
      return uri.hasQuery ? null : AppRoutes.feature('dictionary', level: 'N5');
    case '/vocabulary/alphabet':
      return uri.hasQuery ? null : AppRoutes.feature('alphabet', level: 'N5');
    case '/writing':
      return uri.hasQuery ? null : AppRoutes.feature('writing', level: 'N5');
    case '/exam':
      if (uri.queryParameters.keys.any((key) => key != 'level')) return null;
      return AppRoutes.feature('exam', level: level);
    case '/video-learning':
      if (uri.queryParameters.keys.any((key) => key != 'level')) return null;
      return uri.hasQuery
          ? AppRoutes.feature('video', level: level)
          : '/learn/video';
    case '/grammar':
      if (uri.queryParameters.keys.any(
        (key) => !['tab', 'level', 'lesson', 'pattern'].contains(key),
      )) {
        return null;
      }
      final lesson = uri.queryParameters['lesson'];
      if (lesson != null && !RegExp(r'^[1-9][0-9]{0,10}$').hasMatch(lesson)) {
        return null;
      }
      return Uri(
        path: '/learn/grammar',
        queryParameters: {
          'level': level,
          'lesson': ?lesson,
          'pattern': ?uri.queryParameters['pattern'],
        },
      ).toString();
    default:
      if (uri.hasQuery) return null;
      final match = RegExp(r'^/flashcard(?:/(N[1-5]))?$').firstMatch(uri.path);
      return match == null
          ? null
          : AppRoutes.feature('flashcard', level: match.group(1) ?? 'N5');
  }
}
