import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/api_error_view.dart';
import '../auth/account_repository.dart';
import 'vip_repository.dart';

typedef CheckoutLauncher = Future<bool> Function(Uri url);

class VipScreen extends StatefulWidget {
  const VipScreen({this.checkoutLauncher, super.key});
  final CheckoutLauncher? checkoutLauncher;
  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> with WidgetsBindingObserver {
  late AppController _app;
  int? _session;
  bool _busy = false,
      _confirming = false,
      _historyLoaded = false,
      _uncertain = false;
  bool _openedCheckout = false, _refreshAfterBusy = false;
  List<VipPayment> _history = [];
  VnpayCheckout? _checkout;
  String? _message;
  final _errors = <Object>[];
  bool _current(int session) =>
      mounted && _app.isAuthenticated && _app.api.sessionVersion == session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
    if (_session != _app.api.sessionVersion) {
      _session = _app.api.sessionVersion;
      _history = [];
      _checkout = null;
      _errors.clear();
      _message = null;
      _historyLoaded = false;
      _busy = false;
      _uncertain = false;
      _openedCheckout = false;
      _refreshAfterBusy = false;
      if (_app.isAuthenticated) unawaited(_refresh());
    }
  }

  void _finish(int session) {
    if (!_current(session)) return;
    setState(() => _busy = false);
    if (_refreshAfterBusy) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_busy || !_app.isAuthenticated) return;
    final session = _app.api.sessionVersion;
    _refreshAfterBusy = false;
    setState(() {
      _busy = true;
      _historyLoaded = false;
      _errors.clear();
    });
    Future<void> read(Future<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        if (_current(session)) _errors.add(error);
      }
    }

    await Future.wait([
      read(() async {
        final history = await VipRepository(_app.api).history();
        if (!_current(session)) return;
        _history = history;
        _historyLoaded = true;
        _uncertain = false;
        final order = _checkout?.payment.orderCode;
        final matching = history.where((item) => item.orderCode == order);
        if (matching.isNotEmpty && matching.first.status != 'PENDING') {
          _message =
              'Máy chủ xác nhận đơn $order: ${paymentStatus(matching.first.status)}.';
          _checkout = null;
        }
      }),
      read(() async {
        final profile = await AccountRepository(_app.api).profile();
        if (_current(session)) _app.updateProfile(profile);
      }),
    ]);
    _finish(session);
  }

  Future<void> _create(VipPlan plan) async {
    if (_busy ||
        _confirming ||
        !_historyLoaded ||
        _uncertain ||
        _checkout != null ||
        !_app.isAuthenticated) {
      return;
    }
    final session = _app.api.sessionVersion;
    setState(() => _confirming = true);
    final pending = _history.where((item) => item.status == 'PENDING').length;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Tạo đơn VIP ${plan.months} tháng?'),
          content: Text(
            'Giá niêm yết ${vipMoney(plan.listedAmount)}. Bạn sẽ xem lại số tiền máy chủ xác nhận trước khi mở VNPAY.'
            '${pending > 0 ? '\nBạn đang có $pending đơn chờ xác nhận. Kiểm tra các đơn đã trả tiền trước khi tạo thêm.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('vip-confirm-create'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tạo đơn'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
    if (confirmed != true || !_current(session) || _busy) return;
    setState(() {
      _busy = true;
      _errors.clear();
      _message = null;
    });
    try {
      final checkout = await VipRepository(_app.api).create(plan.months);
      if (_current(session)) setState(() => _checkout = checkout);
    } catch (error) {
      if (_current(session)) {
        setState(() {
          _errors.add(error);
          // A transport/5xx/invalid-response error can happen after order creation.
          _uncertain =
              error is! ApiException ||
              error.status == null ||
              error.status! >= 500;
        });
      }
    } finally {
      _finish(session);
    }
  }

  Future<void> _openCheckout() async {
    final checkout = _checkout;
    if (checkout == null || _busy || !_historyLoaded || !_app.isAuthenticated) {
      return;
    }
    if (checkout.expired) {
      setState(
        () => _message = 'Liên kết đã hết hạn. Kiểm tra trạng thái giao dịch trước khi tạo đơn khác.',
      );
      return;
    }
    final session = _app.api.sessionVersion;
    setState(() {
      _busy = true;
      _errors.clear();
    });
    try {
      _openedCheckout = true;
      final opened =
          await (widget.checkoutLauncher?.call(checkout.url) ??
              launchUrl(checkout.url, mode: LaunchMode.externalApplication));
      if (!_current(session)) return;
      setState(
        () => _message = opened
            ? 'Hoàn tất trên VNPAY rồi quay lại ứng dụng và bấm Kiểm tra thanh toán. Chỉ kết quả máy chủ mới kích hoạt VIP.'
            : 'Chưa mở được trình duyệt. Bấm Mở VNPAY để thử lại đơn này; không cần tạo đơn mới.',
      );
      if (!opened) _openedCheckout = false;
    } catch (_) {
      if (_current(session)) {
        _openedCheckout = false;
        setState(
          () => _message = 'Chưa mở được VNPAY. Thử lại đơn hiện tại sau khi kiểm tra trình duyệt.',
        );
      }
    } finally {
      _finish(session);
    }
  }

  Future<void> _anotherOrder() async {
    if (_busy || _checkout == null) return;
    final session = _app.api.sessionVersion;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn gói khác?'),
        content: const Text(
          'Đơn hiện tại không bị hủy trên máy chủ. Nếu bạn đã trả tiền, hãy kiểm tra thanh toán trước để tránh trả trùng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chọn gói khác'),
          ),
        ],
      ),
    );
    if (confirmed == true && _current(session)) {
      setState(() => _checkout = null);
      await _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _openedCheckout &&
        _app.isAuthenticated) {
      _openedCheckout = false;
      _refreshAfterBusy = true;
      if (!_busy) unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VIP · Thanh toán VNPAY')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_app.isAuthenticated)
            ApiErrorView(
              error: const ApiException(
                'Đăng nhập để nâng cấp VIP và xem giao dịch của bạn.',
                status: 401,
              ),
              onRetry: _refresh,
            )
          else ...[
            Text(
              'Gói hiện tại: ${_app.user?['membership'] ?? 'FREE'}',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            if (_app.user?['vipExpiresAt'] != null)
              Text('Hiệu lực đến: ${_app.user!['vipExpiresAt']}'),
            const SizedBox(height: 12),
            const Text(
              'Nâng cấp hoặc gia hạn VIP dùng chung tài khoản website. Lượt AI và quyền học do máy chủ quản lý. Nếu còn hạn, backend cộng thời gian gia hạn theo quy định của gói.',
            ),
            if (_busy) const LinearProgressIndicator(),
            for (final error in _errors)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  error is ApiException
                      ? error.message
                      : 'Chưa kết nối được dịch vụ thanh toán.',
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            OutlinedButton.icon(
              key: const ValueKey('vip-refresh'),
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Kiểm tra thanh toán và cập nhật VIP'),
            ),
            if (_uncertain)
              const Text(
                'Chưa xác định được kết quả tạo đơn. Tải lịch sử trước khi tạo lại; không tự gửi lại yêu cầu.',
              ),
            if (_checkout case final checkout?) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Đơn ${checkout.payment.orderCode}'),
                      Text(
                        'VIP ${checkout.payment.months} tháng · ${vipMoney(checkout.payment.amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        checkout.sandbox
                            ? 'VNPAY Sandbox · môi trường thử nghiệm'
                            : 'Cổng thanh toán VNPAY',
                      ),
                      const Text(
                        'Kiểm tra gói và số tiền trước khi tiếp tục. Thanh toán thực hiện trên trang VNPAY trong trình duyệt.',
                      ),
                      FilledButton(
                        key: const ValueKey('vip-open-checkout'),
                        onPressed: _busy || !_historyLoaded
                            ? null
                            : _openCheckout,
                        child: const Text('Mở VNPAY để thanh toán'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _anotherOrder,
                        child: const Text('Chọn gói khác'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'Giá niêm yết theo website; số tiền cuối cùng được xác nhận từ máy chủ ở bước tạo đơn.',
              ),
              for (final plan in VipPlan.all)
                Card(
                  child: ListTile(
                    title: Text('VIP ${plan.months} tháng'),
                    subtitle: Text(vipMoney(plan.listedAmount)),
                    trailing: FilledButton(
                      key: ValueKey('vip-plan-${plan.months}'),
                      onPressed:
                          _busy || _confirming || !_historyLoaded || _uncertain
                          ? null
                          : () => _create(plan),
                      child: const Text('Chọn gói'),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Lịch sử giao dịch',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            if (_historyLoaded && _history.isEmpty)
              const Text('Bạn chưa có giao dịch VIP.'),
            for (final payment in _history)
              Card(
                child: ListTile(
                  key: ValueKey('vip-order-${payment.orderCode}'),
                  title: Text(
                    '${payment.orderCode} · ${paymentStatus(payment.status)}',
                  ),
                  subtitle: Text(
                    'VIP ${payment.months} tháng · ${vipMoney(payment.amount)}\n${jsonText(payment.data, 'createdAt')}',
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
