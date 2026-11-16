import 'package:flutter/material.dart';

import '../theme.dart';

/// Точка графика: подпись под осью, значение и подсказка при нажатии.
typedef ChartPoint = ({String label, double value, String tip});

/// Линейный график (п. 105): плавная кривая с заливкой под ней — там, где важен тренд
/// (динамика упражнения, вес тела). Нажатие на точку — подсказка над графиком.
class LineChart extends StatefulWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 120,
  });

  final List<ChartPoint> points;
  final Color color;
  final double height;

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final selected = (_selected ?? points.length - 1).clamp(
      0,
      points.length - 1,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          points[selected].tip,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                if (points.length < 2) return;
                final step = box.maxWidth / (points.length - 1);
                setState(
                  () => _selected = (d.localPosition.dx / step).round().clamp(
                    0,
                    points.length - 1,
                  ),
                );
              },
              child: CustomPaint(
                size: Size(box.maxWidth, widget.height),
                painter: _LinePainter(
                  values: [for (final p in points) p.value],
                  color: widget.color,
                  selected: selected,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              points.first.label,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const Spacer(),
            if (points.length > 1)
              Text(
                points.last.label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.color,
    required this.selected,
  });

  final List<double> values;
  final Color color;
  final int selected;

  /// Отступ сверху и снизу, чтобы точки и линия не резались краем.
  static const _pad = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-6) {
      // Ровная линия — посередине.
      lo -= 1;
      hi += 1;
    }
    final h = size.height - _pad * 2;
    Offset at(int i) => Offset(
      values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1),
      _pad + h * (1 - (values[i] - lo) / (hi - lo)),
    );
    final pts = [for (var i = 0; i < values.length; i++) at(i)];

    // Плавная кривая: середины соседних точек — опорные, сами точки — контрольные.
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = Offset(
        (pts[i - 1].dx + pts[i].dx) / 2,
        (pts[i - 1].dy + pts[i].dy) / 2,
      );
      line.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
    }
    line.lineTo(pts.last.dx, pts.last.dy);

    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    for (final (i, p) in pts.indexed) {
      final active = i == selected;
      canvas.drawCircle(p, active ? 5 : 3, Paint()..color = color);
      if (active) {
        canvas.drawCircle(
          p,
          8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: 0.35),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.color != color || old.selected != selected;
}
