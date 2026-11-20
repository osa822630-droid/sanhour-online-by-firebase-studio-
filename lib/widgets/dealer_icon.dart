// lib/widgets/dealer_icon.dart
// ✅ أيقونة ديلز الاحترافية — مصافحة أنيقة متناسقة مع هوية التطبيق
import 'package:material_ui/material_ui.dart';

class DealerIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showLabel;
  final bool isSelected;

  const DealerIcon({
    super.key,
    this.size = 24,
    this.color,
    this.showLabel = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF3D6B5E);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSelected ? Icons.handshake_rounded : Icons.handshake_outlined,
          size: size,
          color: c,
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            'ديلز',
            style: TextStyle(
              fontSize: size * 0.42,
              color: c,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
