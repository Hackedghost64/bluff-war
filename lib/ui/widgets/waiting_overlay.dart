import 'package:flutter/material.dart';

class WaitingOverlay extends StatelessWidget {
  final String message;
  const WaitingOverlay({super.key, this.message = 'WAITING FOR OPPONENT...'});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 30),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1.0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
