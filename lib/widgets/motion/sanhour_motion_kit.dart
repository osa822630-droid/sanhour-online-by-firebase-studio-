// lib/widgets/motion/sanhour_motion_kit.dart
// مكتبة الحركات والويدجتس التفاعلية لسنهور أونلاين (60fps آمنة على أندرويد 10 + دعم تقليل الحركة)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:material_ui/material_ui.dart';

// ============================================================================
// 1. ShiftCard — انكماش لمسي ناعم (0.975) عند الضغط مع دعم Hero
// ============================================================================
class ShiftCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const ShiftCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.975,
  });

  @override
  State<ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<ShiftCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) {
        if (!reduce && mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// 2. ClickSparkHeart — شرارات المفضلة (8 نقاط في 280ms)
// ============================================================================
class ClickSparkHeart extends StatefulWidget {
  final bool isFavorite;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ClickSparkHeart({
    super.key,
    required this.isFavorite,
    required this.onTap,
    this.onLongPress,
    this.size = 28,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
  });

  @override
  State<ClickSparkHeart> createState() => _ClickSparkHeartState();
}

class _ClickSparkHeartState extends State<ClickSparkHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void didUpdateWidget(covariant ClickSparkHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isFavorite && widget.isFavorite) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      onTap: () {
        if (!widget.isFavorite && !reduce) {
          _ctrl.forward(from: 0);
        }
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: widget.size + 16,
        height: widget.size + 16,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (!reduce)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  if (_ctrl.value == 0 || _ctrl.value == 1) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    size: Size(widget.size + 24, widget.size + 24),
                    painter: _SparkPainter(
                      progress: _ctrl.value,
                      primaryColor: widget.activeColor,
                      accentColor: const Color(0xFFE0A865),
                    ),
                  );
                },
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: widget.isFavorite ? 1.18 : 1.0),
              duration: Duration(milliseconds: reduce ? 0 : 200),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(
                widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: widget.isFavorite
                    ? widget.activeColor
                    : widget.inactiveColor,
                size: widget.size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color accentColor;

  _SparkPainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.55;
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final dotRadius = (3.4 * (1.0 - progress * 0.7)).clamp(0.8, 3.4);

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8.0) * math.pi * 2;
      final dist = maxRadius * Curves.easeOutCubic.transform(progress);
      final pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );
      final paint = Paint()
        ..color = (i.isEven ? primaryColor : accentColor)
            .withValues(alpha: opacity);
      canvas.drawCircle(pos, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// 3. SonnerToast — إشعارات عائمة أعلى الشاشة (بديل أنيق للـ SnackBar)
// ============================================================================
enum SonnerToastType { success, info, warning, error }

class SonnerToast {
  static OverlayEntry? _activeEntry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    SonnerToastType type = SonnerToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    dismiss();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final Color accent = switch (type) {
      SonnerToastType.success => const Color(0xFF2E9E5B),
      SonnerToastType.warning => const Color(0xFFE0A865),
      SonnerToastType.error => const Color(0xFFD94B4B),
      SonnerToastType.info => const Color(0xFF73A899),
    };
    final IconData icon = switch (type) {
      SonnerToastType.success => Icons.check_circle_rounded,
      SonnerToastType.warning => Icons.bolt_rounded,
      SonnerToastType.error => Icons.error_rounded,
      SonnerToastType.info => Icons.info_rounded,
    };

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _SonnerToastWidget(
        message: message,
        icon: icon,
        accent: accent,
        actionLabel: actionLabel,
        onAction: () {
          dismiss();
          onAction?.call();
        },
        onDismiss: dismiss,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _activeEntry?.remove();
    _activeEntry = null;
  }
}

class _SonnerToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _SonnerToastWidget({
    required this.message,
    required this.icon,
    required this.accent,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_SonnerToastWidget> createState() => _SonnerToastWidgetState();
}

class _SonnerToastWidgetState extends State<_SonnerToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top + 12;
    return Positioned(
      top: topPad,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Dismissible(
              key: const ValueKey('sonner_toast'),
              direction: DismissDirection.up,
              onDismissed: (_) => widget.onDismiss(),
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B201E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.accent.withValues(alpha: 0.45),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: widget.accent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null &&
                          widget.onAction != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: widget.onAction,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE0A865),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. FamilyDrawer — درج متمدد الارتفاع تلقائياً للخطوات المتعددة
// ============================================================================
class FamilyDrawer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const FamilyDrawer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B201E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. DirectionAwareTabs & M3EMagneticChip — تبويبات منزلقة وشرائح M3E
// ============================================================================
class DirectionAwareTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  const DirectionAwareTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor = const Color(0xFF3D6B5E),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = tabs.length;
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232927) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemW = constraints.maxWidth / count;
          final isRtl = Directionality.of(context) == TextDirection.rtl;
          final visualIndex =
              isRtl ? (count - 1 - selectedIndex) : selectedIndex;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: visualIndex * itemW,
                  top: 0,
                  bottom: 0,
                  width: itemW,
                  child: Container(
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(count, (i) {
                    final active = i == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontFamily:
                                  Theme.of(context).textTheme.bodyMedium?.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: active
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700),
                            ),
                            child: Text(
                              tabs[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class M3EMagneticChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;

  const M3EMagneticChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = const Color(0xFF3D6B5E),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.25 : 0.14)
              : (isDark ? const Color(0xFF1B201E) : Colors.white),
          borderRadius: BorderRadius.circular(selected ? 10 : 999),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.35),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? color
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? (isDark ? const Color(0xFF73A899) : color)
                    : (isDark ? Colors.grey.shade200 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. CountUpText — عدادات أرقام متحركة بـ tabularFigures
// ============================================================================
class CountUpText extends StatelessWidget {
  final String value;
  final TextStyle? style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(value, style: effectiveStyle);
    }

    final clean = value.replaceAll(',', '').trim();
    final match = RegExp(r'^([^\d\-]*)(\-?\d+(?:\.\d+)?)(.*)$').firstMatch(clean);
    if (match == null) {
      return Text(value, style: effectiveStyle);
    }

    final prefix = match.group(1) ?? '';
    final numStr = match.group(2)!;
    final suffix = match.group(3) ?? '';
    final target = double.tryParse(numStr);
    if (target == null) return Text(value, style: effectiveStyle);
    final decimals = numStr.contains('.') ? numStr.split('.').last.length : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, val, __) {
        final formatted = decimals > 0
            ? val.toStringAsFixed(decimals)
            : val.round().toString();
        return Text('$prefix$formatted$suffix', style: effectiveStyle);
      },
    );
  }
}

// ============================================================================
// 9. TactileButton — الزر الملموس ثلاثي الأبعاد (dqnamo/kitchen)
// ============================================================================
class TactileButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  final bool isLoading;
  final double height;

  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = const Color(0xFF3D6B5E),
    this.isLoading = false,
    this.height = 52,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;

  Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    final faceColor = enabled ? widget.color : Colors.grey.shade500;
    final lipColor = _darken(faceColor);
    const depth = 5.0;

    return GestureDetector(
      onTap: enabled ? widget.onPressed : null,
      onTapDown: (_) {
        if (enabled && mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed && mounted) setState(() => _pressed = false);
      },
      child: SizedBox(
        width: double.infinity,
        height: widget.height + depth,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: depth,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: lipColor,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 75),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _pressed ? depth - 1 : 0,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: faceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _pressed
                      ? const []
                      : [
                          BoxShadow(
                            color: faceColor.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    else if (widget.icon != null)
                      Icon(widget.icon, color: Colors.white, size: 20),
                    if (widget.isLoading || widget.icon != null)
                      const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 10. HoldToConfirmButton — اضغط مطولاً للتأكيد (dqnamo/kitchen)
// ============================================================================
class HoldToConfirmButton extends StatefulWidget {
  final String label;
  final VoidCallback onConfirmed;
  final Color color;
  final Duration holdDuration;

  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.color = const Color(0xFFD94B4B),
    this.holdDuration = const Duration(milliseconds: 1100),
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onConfirmed();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _start() {
    _fired = false;
    _ctrl.forward(from: 0);
  }

  void _cancel() {
    if (!_fired) {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: widget.color, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: _ctrl.value,
                    heightFactor: 1,
                    child: Container(
                      color: widget.color.withValues(alpha: 0.24),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_forever_rounded,
                        color: widget.color, size: 19),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 11. DynamicButton — الزر الديناميكي المتمدد (dqnamo/kitchen)
// ============================================================================
enum DynamicButtonState { idle, loading, success }

class DynamicButton extends StatelessWidget {
  final DynamicButtonState state;
  final String idleLabel;
  final String loadingLabel;
  final String successLabel;
  final VoidCallback? onPressed;
  final Color color;

  const DynamicButton({
    super.key,
    required this.state,
    required this.idleLabel,
    this.loadingLabel = 'جاري الحفظ...',
    this.successLabel = 'تم الحفظ بنجاح',
    required this.onPressed,
    this.color = const Color(0xFF3D6B5E),
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (state) {
      DynamicButtonState.idle => color,
      DynamicButtonState.loading => const Color(0xFF4F5D58),
      DynamicButtonState.success => const Color(0xFF1F8A4C),
    };

    return Center(
      child: GestureDetector(
        onTap: state == DynamicButtonState.idle ? onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: 50,
          width: switch (state) {
            DynamicButtonState.idle => double.infinity,
            DynamicButtonState.loading => 210,
            DynamicButtonState.success => 230,
          },
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(
              state == DynamicButtonState.idle ? 14 : 999,
            ),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: switch (state) {
              DynamicButtonState.idle => Text(
                  idleLabel,
                  key: const ValueKey('idle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              DynamicButtonState.loading => Row(
                  key: const ValueKey('loading'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      loadingLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              DynamicButtonState.success => Row(
                  key: const ValueKey('success'),
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      successLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 12. ReceiptPrinterDialog — إيصال التفعيل المطبوع (dqnamo/kitchen)
// ============================================================================
class ReceiptPrinterDialog extends StatefulWidget {
  final String title;
  final Map<String, String> rows;
  final String? footerNote;

  const ReceiptPrinterDialog({
    super.key,
    required this.title,
    required this.rows,
    this.footerNote,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Map<String, String> rows,
    String? footerNote,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ReceiptPrinterDialog(
        title: title,
        rows: rows,
        footerNote: footerNote,
      ),
    );
  }

  @override
  State<ReceiptPrinterDialog> createState() => _ReceiptPrinterDialogState();
}

class _ReceiptPrinterDialogState extends State<ReceiptPrinterDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _reveal = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // فتحة الطابعة
          Container(
            width: 260,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2623),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
          ClipRect(
            child: SizeTransition(
              sizeFactor: _reveal,
              axisAlignment: -1.0,
              child: Container(
                width: 242,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(14)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: Color(0xFF3D6B5E), size: 34),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF182320),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE0E5E2)),
                    ),
                    ...widget.rows.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                e.value,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: Color(0xFF182320),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.footerNote != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.footerNote!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D6B5E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('تم'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 13. ScrambleText — فك تشفير الأكواد (dqnamo/kitchen)
// ============================================================================
class ScrambleText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;

  const ScrambleText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  State<ScrambleText> createState() => _ScrambleTextState();
}

class _ScrambleTextState extends State<ScrambleText> {
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final _rng = math.Random();
  Timer? _timer;
  late String _display;

  @override
  void initState() {
    super.initState();
    _display = widget.text;
    _startScramble();
  }

  @override
  void didUpdateWidget(covariant ScrambleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startScramble();
    }
  }

  void _startScramble() {
    _timer?.cancel();
    const totalFrames = 14;
    int frame = 0;
    final stepMs = (widget.duration.inMilliseconds / totalFrames).round();
    _timer = Timer.periodic(Duration(milliseconds: stepMs.clamp(20, 60)), (t) {
      frame++;
      final target = widget.text;
      final revealed = ((frame / totalFrames) * target.length).floor();
      final buf = StringBuffer();
      for (int i = 0; i < target.length; i++) {
        if (target[i] == '-' || target[i] == ' ' || i < revealed) {
          buf.write(target[i]);
        } else {
          buf.write(_chars[_rng.nextInt(_chars.length)]);
        }
      }
      if (mounted) {
        setState(() => _display = frame >= totalFrames ? target : buf.toString());
      }
      if (frame >= totalFrames) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      _display,
      style: (widget.style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ============================================================================
// 14a. LogoTraceLoader — رسم خطي للشعار أثناء التحميل (dqnamo/kitchen)
// ============================================================================
class LogoTraceLoader extends StatefulWidget {
  final double size;
  final Color color;

  const LogoTraceLoader({
    super.key,
    this.size = 46,
    this.color = const Color(0xFFE0A865),
  });

  @override
  State<LogoTraceLoader> createState() => _LogoTraceLoaderState();
}

class _LogoTraceLoaderState extends State<LogoTraceLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Icon(Icons.storefront_rounded,
          color: widget.color, size: widget.size * 0.8);
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size.square(widget.size),
        painter: _LogoTracePainter(
          progress: _ctrl.value,
          color: widget.color,
        ),
      ),
    );
  }
}

class _LogoTracePainter extends CustomPainter {
  final double progress;
  final Color color;

  _LogoTracePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.16, h * 0.44)
      ..lineTo(w * 0.50, h * 0.14)
      ..lineTo(w * 0.84, h * 0.44)
      ..lineTo(w * 0.84, h * 0.84)
      ..lineTo(w * 0.60, h * 0.84)
      ..lineTo(w * 0.60, h * 0.58)
      ..lineTo(w * 0.40, h * 0.58)
      ..lineTo(w * 0.40, h * 0.84)
      ..lineTo(w * 0.16, h * 0.84)
      ..close();

    final strokeProgress = (progress / 0.65).clamp(0.0, 1.0);
    final fillOpacity = progress > 0.65
        ? ((1.0 - ((progress - 0.65) / 0.35)) * 0.28).clamp(0.0, 0.28)
        : 0.0;

    if (fillOpacity > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: fillOpacity)
          ..style = PaintingStyle.fill,
      );
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final metric in path.computeMetrics()) {
      final extract = metric.extractPath(0, metric.length * strokeProgress);
      canvas.drawPath(extract, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoTracePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// 14b. ScrollFadeList — تلاشي ناعم عند حواف القوائم (dqnamo/kitchen)
// ============================================================================
class ScrollFadeList extends StatelessWidget {
  final Widget child;
  final Axis axis;
  final double fadeFraction;

  const ScrollFadeList({
    super.key,
    required this.child,
    this.axis = Axis.vertical,
    this.fadeFraction = 0.06,
  });

  @override
  Widget build(BuildContext context) {
    final f = fadeFraction.clamp(0.02, 0.2);
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: axis == Axis.vertical
              ? Alignment.topCenter
              : Alignment.centerLeft,
          end: axis == Axis.vertical
              ? Alignment.bottomCenter
              : Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0.0, f, 1.0 - f, 1.0],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
