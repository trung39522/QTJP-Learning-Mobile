import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/qtjp_colors.dart';
import '../../core/widgets/api_error_view.dart';
import '../../core/widgets/kyuto_scaffold.dart';
import 'feedback_repository.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController();
  late AppController _app;
  int? _session;
  int _tab = 0, _page = 0, _pages = 0, _historyGeneration = 0;
  String _category = 'BUG';
  bool _sending = false, _loading = false, _uncertain = false, _picking = false;
  Uint8List? _image;
  String? _message;
  Object? _error, _historyError;
  List<Map<String, dynamic>> _tickets = [];
  bool _current(int session) =>
      mounted && _app.isAuthenticated && session == _app.api.sessionVersion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _historyGeneration++;
      _title.clear();
      _description.clear();
      _image = null;
      _tickets = [];
      _message = null;
      _error = null;
      _historyError = null;
      _sending = false;
      _loading = false;
      _uncertain = false;
      _picking = false;
      _tab = 0;
      _page = 0;
      _pages = 0;
    }
  }

  Future<void> _history({int page = 0}) async {
    if (!_app.isAuthenticated || _loading || _sending) return;
    final session = _app.api.sessionVersion;
    final generation = ++_historyGeneration;
    setState(() {
      _tab = 1;
      _loading = true;
      _historyError = null;
    });
    try {
      final data = await FeedbackRepository(_app.api).mine(page);
      if (!_current(session) || generation != _historyGeneration) return;
      final tickets = jsonObjects(data['content']);
      final total = data['totalPages'];
      if (total is! int || total < 0) {
        throw const ApiException('Dữ liệu lịch sử chưa hợp lệ.');
      }
      setState(() {
        _tickets = tickets;
        _page = page;
        _pages = total;
        _uncertain = false;
      });
    } catch (error) {
      if (_current(session) && generation == _historyGeneration) {
        setState(() => _historyError = error);
      }
    } finally {
      if (_current(session) && generation == _historyGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    if (_picking || _sending) return;
    final session = _app.api.sessionVersion;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
      if (file == null || !_current(session)) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const ApiException('Ảnh minh họa cần nhỏ hơn 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final png =
          bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
      final jpg =
          bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpg) {
        throw const ApiException('Vui lòng chọn ảnh PNG hoặc JPG.');
      }
      if (_current(session)) setState(() => _image = bytes);
    } catch (error) {
      if (_current(session)) {
        setState(
          () => _error = error is ApiException
              ? error
              : const ApiException('Chưa thể mở ảnh. Vui lòng thử lại.'),
        );
      }
    } finally {
      if (_current(session)) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_sending || _picking || _uncertain || !_form.currentState!.validate()) {
      return;
    }
    final session = _app.api.sessionVersion;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _uncertain = true;
      _error = null;
      _message = null;
    });
    try {
      await FeedbackRepository(_app.api).submit(
        category: _category,
        title: _title.text,
        description: _description.text,
        screenshot: _image,
      );
      if (!_current(session)) return;
      setState(() {
        _uncertain = false;
        _title.clear();
        _description.clear();
        _image = null;
        _message = 'Cảm ơn bạn! QTJP đã nhận được góp ý.';
      });
    } catch (error) {
      if (_current(session)) {
        setState(() {
          _error = error;
          if (error is ApiException &&
              error.status != null &&
              error.status! >= 400 &&
              error.status! < 500 &&
              error.status != 408) {
            _uncertain = false;
          }
        });
      }
    } finally {
      if (_current(session)) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KyutoScaffold(
    appBar: AppBar(title: const Text('Góp ý & Báo lỗi')),
    body: SafeArea(
      top: false,
      child: !_app.isAuthenticated
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ApiErrorView(
                error: const ApiException(
                  'Đăng nhập để gửi và xem phản hồi của bạn.',
                  status: 401,
                ),
                onRetry: () => setState(() {}),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending || _loading
                              ? null
                              : () => setState(() => _tab = 0),
                          child: const Text('Gửi góp ý'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending || _loading
                              ? null
                              : () => _history(),
                          child: const Text('Phản hồi của tôi'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: _tab == 0 ? _compose() : _historyView(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _compose() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _message!,
              style: const TextStyle(color: Color(0xFF21845B)),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error.toString(),
              style: const TextStyle(color: QTJPColors.red),
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Chủ đề góp ý'),
          items: feedbackCategories.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: _sending
              ? null
              : (value) => setState(() => _category = value!),
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: const ValueKey('feedback-title'),
          controller: _title,
          enabled: !_sending,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Tiêu đề'),
          validator: (v) =>
              (v ?? '').trim().length < 5 ? 'Nhập ít nhất 5 ký tự.' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('feedback-description'),
          controller: _description,
          enabled: !_sending,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Nội dung chi tiết',
            alignLabelWithHint: true,
          ),
          validator: (v) =>
              (v ?? '').trim().length < 10 ? 'Nhập ít nhất 10 ký tự.' : null,
        ),
        if (_image != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _image!,
              height: 160,
              cacheWidth: 600,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text('Không thể xem trước ảnh.'),
            ),
          ),
          TextButton(
            onPressed: _sending ? null : () => setState(() => _image = null),
            child: const Text('Xóa ảnh'),
          ),
        ] else
          OutlinedButton.icon(
            onPressed: _sending || _picking ? null : _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_picking ? 'Đang mở ảnh…' : 'Đính kèm ảnh'),
          ),
        if (_image == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'PNG hoặc JPG · Tối đa 5 MB',
              style: TextStyle(color: context.qtjp.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Góp ý được gửi riêng cho quản trị viên.',
          style: TextStyle(color: context.qtjp.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (_uncertain && !_sending)
          TextButton(
            onPressed: () => _history(),
            child: const Text('Kiểm tra lịch sử trước khi gửi lại'),
          ),
        FilledButton.icon(
          key: const ValueKey('feedback-submit'),
          onPressed: _sending || _uncertain || _picking ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(_sending ? 'Đang gửi…' : 'Gửi góp ý'),
        ),
      ],
    ),
  );

  Widget _historyView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Phản hồi của tôi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Tải lại phản hồi',
            onPressed: _loading ? null : () => _history(page: _page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (_loading)
        const Center(child: CircularProgressIndicator())
      else if (_historyError != null)
        ApiErrorView(
          error: _historyError!,
          onRetry: () => _history(page: _page),
        )
      else if (_tickets.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Bạn chưa gửi góp ý nào.'),
        )
      else ...[
        for (final ticket in _tickets)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    feedbackCategories[ticket['category']] ?? 'Góp ý',
                    style: TextStyle(color: context.qtjp.blue, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    jsonText(ticket, 'title'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    jsonText(ticket, 'description'),
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    const {
                          'NEW': 'Đã tiếp nhận',
                          'IN_PROGRESS': 'Đang xử lý',
                          'RESOLVED': 'Đã giải quyết',
                          'REJECTED': 'Đã đóng',
                        }[ticket['status']] ??
                        jsonText(ticket, 'status'),
                    style: TextStyle(color: context.qtjp.muted, fontSize: 12),
                  ),
                  if (ticket['hasScreenshot'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Đã gửi kèm ảnh minh họa',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (jsonText(ticket, 'adminReply').isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'QTJP Learning đã phản hồi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(jsonText(ticket, 'adminReply')),
                  ],
                ],
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: TextButton(
                onPressed: _page > 0 ? () => _history(page: _page - 1) : null,
                child: const Text('Trang trước', textAlign: TextAlign.center),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${_page + 1} / $_pages',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: _page + 1 < _pages
                    ? () => _history(page: _page + 1)
                    : null,
                child: const Text('Trang sau', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
