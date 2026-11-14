import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/theme/qtjp_colors.dart';
import '../../profile/models/account_presentation.dart';

class HomeAccountAvatar extends StatelessWidget {
  const HomeAccountAvatar({
    this.onPressed,
    this.radius = 17,
    this.plain = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final double radius;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final account = AccountPresentation(app.user);
    final avatar = app.isAuthenticated
        ? account.avatarUri(app.api.baseUrl)
        : null;
    final vip = app.isAuthenticated && account.vipAt(DateTime.now());
    final face = Semantics(
      image: true,
      label: app.isAuthenticated
          ? 'Ảnh đại diện của ${account.name}'
          : 'Tài khoản khách',
      child: SizedBox.square(
        dimension: radius * 2 + 8,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vip ? const Color(0xFFFFD600) : QTJPColors.border,
                    width: vip ? 3 : 1,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(vip ? 3 : 2),
                  child: CircleAvatar(
                    radius: radius,
                    backgroundColor: QTJPColors.navy,
                    foregroundImage: avatar == null
                        ? null
                        : NetworkImage(avatar.toString()),
                    onForegroundImageError: avatar == null ? null : (_, _) {},
                    child: app.isAuthenticated
                        ? Text(
                            account.name.characters.first.toUpperCase(),
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: radius * 0.9,
                            ),
                          )
                        : Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white,
                            size: radius * 1.3,
                          ),
                  ),
                ),
              ),
            ),
            if (vip)
              Positioned(
                right: radius * -0.06,
                top: radius * -0.13,
                child: ExcludeSemantics(
                  child: SizedBox(
                    key: const ValueKey('vip-crown'),
                    width: radius * 0.86,
                    height: radius * 0.68,
                    child: Transform.rotate(
                      key: const ValueKey('vip-crown-rotation'),
                      angle:
                          0.436332313, // 25 degrees, base attached to the rim.
                      child: const CustomPaint(painter: _CrownPainter()),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (plain || radius > 20) return face;
    return IconButton(
      key: const ValueKey('home-account-avatar'),
      tooltip: app.isAuthenticated ? 'Tài khoản: ${account.name}' : 'Tài khoản',
      onPressed: onPressed,
      padding: const EdgeInsets.all(5),
      icon: face,
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()..color = const Color(0xFFFFC900);
    final crown = Path()
      ..moveTo(size.width * 0.12, size.height * 0.28)
      ..lineTo(size.width * 0.3, size.height * 0.48)
      ..lineTo(size.width * 0.5, size.height * 0.1)
      ..lineTo(size.width * 0.7, size.height * 0.48)
      ..lineTo(size.width * 0.88, size.height * 0.28)
      ..lineTo(size.width * 0.78, size.height * 0.8)
      ..lineTo(size.width * 0.22, size.height * 0.8)
      ..close();
    canvas.drawPath(crown, gold);
    for (final point in [
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.5, size.height * 0.08),
      Offset(size.width * 0.88, size.height * 0.18),
    ]) {
      canvas.drawCircle(point, size.width * 0.07, gold);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.22,
          size.height * 0.88,
          size.width * 0.56,
          size.height * 0.1,
        ),
        const Radius.circular(1),
      ),
      gold,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}
