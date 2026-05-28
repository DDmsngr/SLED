import 'package:flutter/material.dart';

import '../../domain/entities/track_session.dart';

/// График скорости по времени (CustomPainter, без внешних зависимостей).
class SpeedChartWidget extends StatelessWidget {
  const SpeedChartWidget({super.key, required this.session});

  final TrackSession session;

  @override
  Widget build(BuildContext context) {
    final points = session.points;
    if (points.length < 2) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('Недостаточно точек для графика',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final speeds = points.map((p) => p.speedMs * 3.6).toList();
    final totalDuration = points.last.timestamp
        .difference(points.first.timestamp);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('График скорости', style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: CustomPaint(
              painter: _SpeedPainter(
                speeds: speeds,
                totalDuration: totalDuration,
                lineColor: theme.colorScheme.primary,
                fillColor: theme.colorScheme.primary.withOpacity(0.12),
                gridColor: theme.colorScheme.outlineVariant,
                labelStyle: theme.textTheme.labelSmall!
                    .copyWith(color: theme.colorScheme.outline),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter({
    required this.speeds,
    required this.totalDuration,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<double> speeds;
  final Duration totalDuration;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (speeds.isEmpty) return;

    final maxSpd = speeds.reduce((a, b) => a > b ? a : b);
    final maxY = maxSpd < 1 ? 1.0 : (maxSpd * 1.15).ceilToDouble();

    const leftPad = 36.0;
    const bottomPad = 20.0;
    final w = size.width - leftPad;
    final h = size.height - bottomPad;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    // Горизонтальные линии сетки (3 линии: 0, 50%, 100%)
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = h - frac * h;
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final label = '${(frac * maxY).round()} км/ч';
      _drawText(canvas, label, Offset(0, y - 7));
    }

    if (speeds.length < 2) return;

    // Путь линии и заливки
    final path = Path();
    final fill = Path();

    for (int i = 0; i < speeds.length; i++) {
      final x = leftPad + (i / (speeds.length - 1)) * w;
      final y = h - (speeds[i] / maxY).clamp(0.0, 1.0) * h;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, h);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }

    fill.lineTo(size.width, h);
    fill.close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    // Метки времени по оси X
    _drawText(canvas, '0', Offset(leftPad - 4, size.height - 14));
    final midLabel = _durLabel(totalDuration ~/ 2);
    final endLabel = _durLabel(totalDuration);
    _drawText(canvas, midLabel,
        Offset(leftPad + w / 2 - 12, size.height - 14));
    _drawText(canvas, endLabel,
        Offset(size.width - 28, size.height - 14));
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  String _durLabel(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$m';
  }

  @override
  bool shouldRepaint(_SpeedPainter old) =>
      old.speeds != speeds || old.totalDuration != totalDuration;
}
