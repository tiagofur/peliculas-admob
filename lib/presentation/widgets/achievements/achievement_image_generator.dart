import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/achievement.dart';

class AchievementImageGenerator extends StatelessWidget {
  const AchievementImageGenerator({
    super.key,
    required this.achievement,
    required this.repaintBoundaryKey,
  });
  final Achievement achievement;
  final GlobalKey repaintBoundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        width: 400,
        height: 600,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Patrón de fondo cinematográfico
            Positioned.fill(
              child: CustomPaint(
                painter: CinematicPatternPainter(),
              ),
            ),
            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header con branding
                  _buildHeader(),
                  const SizedBox(height: 40),
                  // Ícono del logro
                  _buildAchievementIcon(),
                  const SizedBox(height: 24),
                  // Título del logro
                  _buildAchievementTitle(),
                  const SizedBox(height: 16),
                  // Descripción del logro
                  _buildAchievementDescription(),
                  const Spacer(),
                  // Fecha de desbloqueo
                  _buildUnlockDate(),
                  const SizedBox(height: 20),
                  // Footer
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE94560).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE94560),
              width: 1,
            ),
          ),
          child: const Text(
            '🎬 PELÍCULAS',
            style: TextStyle(
              color: Color(0xFFE94560),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'LOGRO DESBLOQUEADO',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFFA500),
            Color(0xFFFF8C00),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          achievement.iconName.isNotEmpty ? achievement.iconName : '🏆',
          style: const TextStyle(
            fontSize: 48,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementTitle() {
    return Text(
      achievement.title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
    );
  }

  Widget _buildAchievementDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        achievement.description,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildUnlockDate() {
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule,
            color: Colors.white70,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Desbloqueado: ${achievement.unlockedDate != null ? dateFormat.format(achievement.unlockedDate!) : 'Ahora'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE94560).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        '¡Sigue descubriendo películas increíbles!',
        style: TextStyle(
          color: Color(0xFFE94560),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // Método estático para generar y guardar la imagen
  static Future<File?> generateImage(Achievement achievement) async {
    try {
      // Por ahora, retornamos null para usar el fallback de texto
      // La generación de imagen requiere un enfoque más complejo
      return null;
    } catch (e) {
      return null;
    }
  }
}

// Painter personalizado para el patrón cinematográfico
class CinematicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Líneas diagonales
    for (int i = 0; i < 20; i++) {
      final x = (size.width / 20) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.3, size.height),
        paint,
      );
    }

    // Círculos decorativos
    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.2),
      30,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.9, size.height * 0.8),
      40,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
