import 'package:flutter/material.dart';

class CanvasAppIcon extends StatelessWidget {
  final double size;
  const CanvasAppIcon({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AppIconPainter(),
      ),
    );
  }
}

class _AppIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Deep metallic background
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF0D1117), const Color(0xFF161B22), const Color(0xFF30363D)],
      ).createShader(rect);
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.2));
    canvas.drawRRect(rrect, bgPaint);

    // Glowing border
    final borderPaint = Paint()
      ..color = const Color(0xFFF85149)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, size.width * 0.02);
    canvas.drawRRect(rrect, borderPaint);

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    // Crossed Swords (Stylized)
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    
    for (var angle in [-0.7, 0.7]) {
      canvas.save();
      canvas.rotate(angle);
      // Blade
      canvas.drawLine(Offset(0, -size.height * 0.35), Offset(0, size.height * 0.1), linePaint);
      // Guard
      canvas.drawLine(Offset(-size.width * 0.1, size.height * 0.1), Offset(size.width * 0.1, size.height * 0.1), 
        linePaint..strokeWidth = size.width * 0.04);
      // Handle
      canvas.drawLine(Offset(0, size.height * 0.1), Offset(0, size.height * 0.25), 
        linePaint..strokeWidth = size.width * 0.06..color = Colors.amber);
      canvas.restore();
    }
    
    canvas.restore();

    // Central Glow
    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.15);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.width * 0.2, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
