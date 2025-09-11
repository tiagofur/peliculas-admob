import 'package:flutter/material.dart';

import '../core/gamification/challenge_system.dart';

class ChallengeCompletionCelebration extends StatelessWidget {
  const ChallengeCompletionCelebration({
    super.key,
    required this.challenge,
    required this.pointsEarned,
    this.badgeEarned,
    required this.onDismiss,
  });

  final Challenge challenge;
  final int pointsEarned;
  final String? badgeEarned;
  final void Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Center(
            child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Trophy icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 50,
                          color: Colors.orange,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Challenge completed text
                      const Text(
                        '¡Desafío Completado!',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Challenge name
                      Text(
                        challenge.title,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Points earned
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$pointsEarned puntos',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Dismiss button
                      ElevatedButton(
                        onPressed: onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text('¡Genial!'),
                      ),
                    ],
                  ),
                ),
              ),

          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show challenge completion celebration
void showChallengeCompletionCelebration(
  BuildContext context,
  Challenge challenge,
  int pointsEarned,
  String? badgeEarned,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ChallengeCompletionCelebration(
      challenge: challenge,
      pointsEarned: pointsEarned,
      badgeEarned: badgeEarned,
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}
