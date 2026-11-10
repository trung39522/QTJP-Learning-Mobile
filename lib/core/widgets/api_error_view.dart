import 'package:flutter/material.dart';

import '../navigation/app_routes.dart';
import '../network/api_client.dart';
import '../theme/qtjp_colors.dart';

class ApiErrorView extends StatelessWidget {
  const ApiErrorView({required this.error, required this.onRetry, super.key});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final needsLogin =
        error is ApiException && (error as ApiException).requiresLogin;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            needsLogin ? Icons.lock_outline : Icons.cloud_off_outlined,
            size: 42,
            color: QTJPColors.blue,
          ),
          const SizedBox(height: 12),
          Text(
            error is ApiException
                ? error.toString()
                : 'Không thể tải dữ liệu. Vui lòng thử lại.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          if (needsLogin)
            FilledButton(
              onPressed: () async {
                await Navigator.of(context).pushNamed(AppRoutes.login);
                if (context.mounted) onRetry();
              },
              child: const Text('Đăng nhập để học'),
            )
          else
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
