import 'package:flutter/material.dart';

/// Pixel-perfect vector painter for the official Google 4-color 'G' brand mark.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    // 1. Blue (Horizontal bar & right side)
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.675, 10.73, 23.545, 10.01)
      ..lineTo(12.0, 10.01)
      ..lineTo(12.0, 14.73)
      ..lineTo(18.585, 14.73)
      ..cubicTo(18.3, 16.27, 17.43, 17.58, 16.125, 18.45)
      ..lineTo(16.125, 21.54)
      ..lineTo(20.105, 21.54)
      ..cubicTo(22.435, 19.39, 23.745, 16.23, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // 2. Green (Bottom curve)
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.96, 22.92, 19.98, 21.05)
      ..lineTo(16.0, 17.96)
      ..cubicTo(14.9, 18.7, 13.51, 19.18, 12.0, 19.18)
      ..cubicTo(8.87, 19.18, 6.22, 17.06, 5.27, 14.21)
      ..lineTo(1.16, 14.21)
      ..lineTo(1.16, 17.39)
      ..cubicTo(3.19, 21.42, 7.27, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // 3. Yellow (Left curve)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.27, 14.21)
      ..cubicTo(5.03, 13.36, 4.9, 12.46, 4.9, 11.53)
      ..cubicTo(4.9, 10.6, 5.03, 9.7, 5.27, 8.85)
      ..lineTo(5.27, 5.67)
      ..lineTo(1.16, 5.67)
      ..cubicTo(0.42, 7.42, 0.0, 9.38, 0.0, 11.53)
      ..cubicTo(0.0, 13.68, 0.42, 15.64, 1.16, 17.39)
      ..lineTo(5.27, 14.21)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 4. Red (Top curve)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.08, 3.07)
      ..cubicTo(17.95, 1.09, 15.23, 0.0, 12.0, 0.0)
      ..cubicTo(7.27, 0.0, 3.19, 2.58, 1.16, 6.61)
      ..lineTo(5.27, 9.79)
      ..cubicTo(6.22, 6.94, 8.87, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official Google 'G' vector mark
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

/// Google Identity Services compliant button (Spotify/Linear style)
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Google ile Devam Et',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF131314) : Colors.white;
    final textColor = isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    final borderColor = isDark ? const Color(0xFF444746) : const Color(0xFFDADCE0);

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        elevation: isDark ? 0 : 0.5,
        shadowColor: Colors.black26,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GoogleLogo(size: 20),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
