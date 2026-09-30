// lib/widgets/analytics_charts.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ✅ Widget مجمعة (حاوية)
class AnalyticsCharts extends StatelessWidget {
  const AnalyticsCharts({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('مكتبة الرسوم البيانية جاهزة للاستخدام',
          style: TextStyle(color: Colors.grey)),
    );
  }
}

// ✅ موديل البيانات
class ChartData {
  final String label;
  final double value;
  final Color color;

  const ChartData({
    required this.label,
    required this.value,
    this.color = Colors.blue,
  });
}

// =========================================================
// 1. رسم بياني بالأعمدة (Bar Chart) - ذكي (Scrollable / Fit)
// =========================================================
class BarChartWidget extends StatelessWidget {
  final List<ChartData> data;
  final double maxValue;
  final Color barColor;
  final double barWidth;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.maxValue,
    this.barColor = Colors.blue,
    this.barWidth = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight =
            constraints.maxHeight > 0 ? constraints.maxHeight : 200;
        final double availableWidth = constraints.maxWidth;

        // حساب ما إذا كنا نحتاج لتفعيل السكرول (لو الأعمدة كتير)
        // بنفترض أن كل عمود محتاج على الأقل (عرضه + 20 بيكسل هوامش)
        final double minItemWidth = barWidth + 24;
        final double requiredWidth = data.length * minItemWidth;
        final bool isScrollable = requiredWidth > availableWidth;

        Widget chartContent = Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          // لو سكرول => ابدأ من الأول، لو لأ => وزعهم بالتساوي
          mainAxisAlignment: isScrollable
              ? MainAxisAlignment.start
              : MainAxisAlignment.spaceEvenly,
          children: data.map((item) {
            final double barPercentage =
                maxValue == 0 ? 0.0 : (item.value / maxValue);
            // نترك 30 بيكسل للنصوص بالأسفل
            final double maxBarHeight = availableHeight - 30;
            final double barHeight = maxBarHeight * barPercentage;

            return Padding(
              // لو سكرول بنضيف هوامش بين الأعمدة، لو لأ الـ spaceEvenly بيقوم بالواجب
              padding: isScrollable
                  ? const EdgeInsets.symmetric(horizontal: 12)
                  : EdgeInsets.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '${item.label}: ${item.value.toInt()}',
                    child: Container(
                      width: barWidth,
                      height: barHeight > 0 ? barHeight : 0,
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [item.color.withValues(alpha: 0.7), item.color],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: barWidth + 20,
                    child: Text(
                      item.label,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black87),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${item.value.toInt()}',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }).toList(),
        );

        if (isScrollable) {
          return SizedBox(
            height: availableHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                // نضمن أنه ياخد العرض المتاح على الأقل
                constraints: BoxConstraints(minWidth: availableWidth),
                child: chartContent,
              ),
            ),
          );
        }

        return SizedBox(height: availableHeight, child: chartContent);
      },
    );
  }
}

// =========================================================
// 2. رسم بياني خطي (Line Chart) - مع تدرج لوني (Area)
// =========================================================
class LineChartWidget extends StatelessWidget {
  final List<ChartData> data;
  final double maxValue;
  final Color lineColor;
  final bool showPoints;
  final bool showGradient; // ✅ ميزة جديدة: تلوين تحت الخط

  const LineChartWidget({
    super.key,
    required this.data,
    required this.maxValue,
    this.lineColor = Colors.blue,
    this.showPoints = true,
    this.showGradient = true, // مفعل افتراضياً لشكل أجمل
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        width: double.infinity,
        height: constraints.maxHeight > 0 ? constraints.maxHeight : 200,
        padding: const EdgeInsets.fromLTRB(
            10, 10, 20, 20), // Padding عشان النقاط متتقطعش
        child: CustomPaint(
          painter: LineChartPainter(
            data: data,
            maxValue: maxValue,
            lineColor: lineColor,
            showPoints: showPoints,
            showGradient: showGradient,
          ),
        ),
      );
    });
  }
}

class LineChartPainter extends CustomPainter {
  final List<ChartData> data;
  final double maxValue;
  final Color lineColor;
  final bool showPoints;
  final bool showGradient;

  LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.lineColor,
    required this.showPoints,
    required this.showGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    // رسم خطوط الشبكة الخلفية
    for (int i = 0; i <= 3; i++) {
      double y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final widthStep = data.length > 1 ? size.width / (data.length - 1) : 0.0;

    // بناء المسار
    for (int i = 0; i < data.length; i++) {
      final x = i * widthStep;
      final y = size.height -
          (maxValue == 0 ? 0 : (data[i].value / maxValue) * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final double prevX = (i - 1) * widthStep;
        final double prevY = size.height -
            (maxValue == 0 ? 0 : (data[i - 1].value / maxValue) * size.height);

        // منحنى ناعم (Cubic Bezier)
        final double controlPointX = prevX + (x - prevX) / 2;
        path.cubicTo(controlPointX, prevY, controlPointX, y, x, y);
      }
    }

    // ✅ رسم التدرج اللوني تحت الخط (Area Chart Effect)
    if (showGradient) {
      final gradientPath = Path.from(path);
      gradientPath.lineTo(size.width, size.height); // للركن السفلي الأيمن
      gradientPath.lineTo(0, size.height); // للركن السفلي الأيسر
      gradientPath.close();

      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.3),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;

      canvas.drawPath(gradientPath, gradientPaint);
    }

    // رسم الخط الرئيسي
    canvas.drawPath(path, paint);

    // رسم النقاط
    if (showPoints) {
      for (int i = 0; i < data.length; i++) {
        final x = i * widthStep;
        final y = size.height -
            (maxValue == 0 ? 0 : (data[i].value / maxValue) * size.height);

        canvas.drawCircle(Offset(x, y), 5, Paint()..color = lineColor);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}

// =========================================================
// 3. رسم بياني دائري (Pie Chart)
// =========================================================
class PieChartWidget extends StatelessWidget {
  final List<ChartData> data;
  final double size;

  const PieChartWidget({super.key, required this.data, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: PieChartPainter(data: data)),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<ChartData> data;
  PieChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final total = data.fold(0.0, (sum, item) => sum + item.value);
    if (total == 0) return;

    var startAngle = -math.pi / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepAngle, true, paint);

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) =>
      oldDelegate.data != data;
}
