import '../../core/network/api_client.dart';

class VipPlan {
  const VipPlan(this.months, this.listedAmount);
  final int months, listedAmount;
  // Published website/backend plans. The final amount always comes from create.
  static const all = [
    VipPlan(1, 49000),
    VipPlan(3, 129000),
    VipPlan(6, 229000),
    VipPlan(12, 399000),
  ];
}

String vipMoney(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
String paymentStatus(String status) => switch (status) {
  'SUCCESS' => 'Thành công',
  'PENDING' => 'Đang chờ xác nhận',
  'FAILED' => 'Thất bại',
  'CANCELLED' => 'Đã hủy',
  _ => 'Chưa xác định',
};

class VipPayment {
  VipPayment.fromJson(this.data)
    : orderCode = jsonText(data, 'orderCode'),
      months = data['months'] is int ? data['months'] as int : 0,
      amount = data['amount'] is int ? data['amount'] as int : 0,
      status = jsonText(data, 'status').toUpperCase() {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(orderCode) ||
        months <= 0 ||
        amount <= 0 ||
        !['PENDING', 'SUCCESS', 'FAILED', 'CANCELLED'].contains(status)) {
      throw const ApiException('Dữ liệu giao dịch từ máy chủ không hợp lệ.');
    }
  }
  final Map<String, dynamic> data;
  final String orderCode, status;
  final int months, amount;
}

class VnpayCheckout {
  VnpayCheckout.fromJson(Map<String, dynamic> data)
    : payment = VipPayment.fromJson(data),
      url = Uri.parse(jsonText(data, 'paymentUrl')) {
    final validEndpoint =
        url.host == 'sandbox.vnpayment.vn' &&
            url.path == '/paymentv2/vpcpay.html' ||
        url.host == 'pay.vnpay.vn' && url.path == '/vpcpay.html';
    final query = url.queryParameters;
    if (!validEndpoint ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        url.hasFragment ||
        payment.status != 'PENDING' ||
        url.queryParametersAll.values.any((values) => values.length != 1) ||
        query['vnp_TxnRef'] != payment.orderCode ||
        query['vnp_Amount'] != '${payment.amount * 100}' ||
        query['vnp_CurrCode'] != 'VND' ||
        !RegExp(r'^[a-fA-F0-9]{128}$')
            .hasMatch(query['vnp_SecureHash'] ?? '')) {
      throw const ApiException(
        'Đường dẫn thanh toán không hợp lệ. Hãy kiểm tra lịch sử trước khi tạo đơn khác.',
      );
    }
  }
  final VipPayment payment;
  final Uri url;
  bool get sandbox => url.host == 'sandbox.vnpayment.vn';
  bool get expired {
    final value = url.queryParameters['vnp_ExpireDate'] ?? '';
    if (!RegExp(r'^\d{14}$').hasMatch(value)) return true;
    final expiry = DateTime.tryParse(
      '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}T${value.substring(8, 10)}:${value.substring(10, 12)}:${value.substring(12, 14)}+07:00',
    );
    return expiry == null || !expiry.isAfter(DateTime.now());
  }
}

class VipRepository {
  const VipRepository(this.api);
  final ApiClient api;
  Future<List<VipPayment>> history() async => jsonObjects(
    await api.get('/api/payments/vnpay/history', authenticated: true),
  ).map(VipPayment.fromJson).toList(growable: false);
  Future<VnpayCheckout> create(int months) async {
    if (!VipPlan.all.any((plan) => plan.months == months)) {
      throw const ApiException('Gói VIP không hợp lệ.');
    }
    final response = await api.request(
      'POST',
      '/api/payments/vnpay/create',
      authenticated: true,
      body: {'months': months},
    );
    try {
      final checkout = VnpayCheckout.fromJson(jsonObject(response));
      if (checkout.payment.months != months) {
        throw const FormatException('Plan mismatch');
      }
      return checkout;
    } catch (_) {
      throw const ApiException(
        'Máy chủ có thể đã tạo đơn nhưng phản hồi chưa hợp lệ. Kiểm tra lịch sử trước khi tạo đơn khác.',
        code: 'PAYMENT_RESULT_UNKNOWN',
      );
    }
  }
}
