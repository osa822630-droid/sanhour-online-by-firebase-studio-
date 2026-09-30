// lib/widgets/dealer_icon.dart
// ✅ أيقونة سنهور ديلر المحترفة — موتوسيكل توصيل واضح وجميل
import 'package:flutter/material.dart';

class DealerIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showLabel;

  const DealerIcon({
    super.key,
    this.size = 28,
    this.color,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF5E35B1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.8,
          height: size,
          child: CustomPaint(painter: _DeliveryBikePainter(color: c)),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            'ديلر',
            style: TextStyle(
              fontSize: size * 0.32,
              color: c,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _DeliveryBikePainter extends CustomPainter {
  final Color color;
  const _DeliveryBikePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.038;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── مواضع العناصر ─────────────────────────────────────────────
    // العجلة الأمامية (يسار في RTL عرض)
    final frontWheelX = w * 0.22;
    final rearWheelX = w * 0.78;
    final wheelY = h * 0.76;
    final wheelR = h * 0.17;

    // ── العجلة الأمامية ───────────────────────────────────────────
    canvas.drawCircle(Offset(frontWheelX, wheelY), wheelR, stroke);
    canvas.drawCircle(Offset(frontWheelX, wheelY), wheelR * 0.2, fill);

    // ── العجلة الخلفية ────────────────────────────────────────────
    canvas.drawCircle(Offset(rearWheelX, wheelY), wheelR, stroke);
    canvas.drawCircle(Offset(rearWheelX, wheelY), wheelR * 0.2, fill);

    // ── هيكل الموتوسيكل (إطار مبسط وواضح) ───────────────────────
    final frame = Path()
      ..moveTo(frontWheelX + wheelR * 0.7, wheelY - wheelR * 0.3) // حامل عجلة أمام
      ..lineTo(w * 0.38, h * 0.48) // وسط الهيكل
      ..lineTo(w * 0.55, h * 0.48) // وصلة الصندوق
      ..moveTo(w * 0.38, h * 0.48) // من وسط الهيكل
      ..lineTo(rearWheelX - wheelR * 0.7, wheelY - wheelR * 0.3); // حامل عجلة خلف
    canvas.drawPath(frame, stroke);

    // ── المقود (فوق العجلة الأمامية) ──────────────────────────────
    canvas.drawLine(
      Offset(frontWheelX - w * 0.07, h * 0.28),
      Offset(frontWheelX + w * 0.07, h * 0.28),
      stroke,
    );
    canvas.drawLine(
      Offset(frontWheelX, h * 0.28),
      Offset(frontWheelX + wheelR * 0.3, wheelY - wheelR * 0.7),
      stroke,
    );

    // ── المقعد (خط منحنٍ) ─────────────────────────────────────────
    final seat = Path()
      ..moveTo(w * 0.36, h * 0.38)
      ..cubicTo(w * 0.42, h * 0.30, w * 0.50, h * 0.30, w * 0.56, h * 0.38);
    canvas.drawPath(seat, stroke..strokeWidth = w * 0.044);
    stroke.strokeWidth = w * 0.038;

    // ── صندوق التوصيل (على العجلة الخلفية) ───────────────────────
    final boxL = w * 0.60;
    final boxT = h * 0.10;
    final boxR = w * 0.96;
    final boxB = h * 0.50;
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(boxL, boxT, boxR, boxB),
      const Radius.circular(5),
    );

    // خلفية الصندوق
    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = color.withValues(alpha: 0.13)
        ..style = PaintingStyle.fill,
    );
    // حدود الصندوق
    canvas.drawRRect(boxRect, stroke..strokeWidth = w * 0.036);
    stroke.strokeWidth = w * 0.038;

    // خط أفقي وسط الصندوق (غطاء)
    canvas.drawLine(
      Offset(boxL, boxT + (boxB - boxT) * 0.38),
      Offset(boxR, boxT + (boxB - boxT) * 0.38),
      stroke..strokeWidth = w * 0.025,
    );
    stroke.strokeWidth = w * 0.038;

    // نجمة (مزخرفة) وسط الصندوق
    _drawCross(canvas, Offset((boxL + boxR) / 2, boxT + (boxB - boxT) * 0.68),
        w * 0.055, fill);

    // ── وصلة الصندوق بالهيكل ──────────────────────────────────────
    canvas.drawLine(
      Offset(boxL, h * 0.50),
      Offset(rearWheelX - wheelR * 0.5, wheelY - wheelR * 0.5),
      stroke,
    );

    // ── رأس السائق (بيضاوي) ─────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.31, h * 0.18),
        width: w * 0.11,
        height: h * 0.15,
      ),
      stroke,
    );
  }

  void _drawCross(Canvas canvas, Offset center, double r, Paint fill) {
    final p = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx, center.dy + r)
      ..moveTo(center.dx - r, center.dy)
      ..lineTo(center.dx + r, center.dy);
    canvas.drawPath(
        p,
        Paint()
          ..color = fill.color
          ..strokeWidth = r * 0.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_DeliveryBikePainter old) => old.color != color;
}
