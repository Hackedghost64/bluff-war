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
    final bgPaint = Paint()
      ..color = const Color(0xFF161B22)
      ..style = PaintingStyle.fill;
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.2));
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF58A6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    canvas.drawRRect(rrect, borderPaint);

    final cardPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw two cards overlapping
    canvas.save();
    canvas.translate(size.width * 0.3, size.height * 0.4);
    canvas.rotate(-0.2);
    final card1 = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * 0.3, size.height * 0.4), Radius.circular(size.width * 0.05));
    canvas.drawRRect(card1, cardPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(size.width * 0.45, size.height * 0.3);
    canvas.rotate(0.2);
    final card2 = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * 0.3, size.height * 0.4), Radius.circular(size.width * 0.05));
    canvas.drawRRect(card2, cardPaint);
    
    // Draw a question mark in the second card
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(color: const Color(0xFFF85149), fontSize: size.width * 0.25, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width * 0.15 - textPainter.width / 2, size.height * 0.2 - textPainter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
