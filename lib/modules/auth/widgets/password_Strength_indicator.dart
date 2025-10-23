
import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
  }) : super(key: key);

  PasswordStrength _calculateStrength() {
    int score = 0;
    List<String> feedback = [];

    if (password.length >= 8) {
      score += 1;
    } else {
      feedback.add('8+ caracteres');
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('letra minúscula');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('letra maiúscula');
    }

    if (RegExp(r'\d').hasMatch(password)) {
      score += 1;
    } else {
      feedback.add('número');
    }

    if (RegExp(r'[@$!%*?&]').hasMatch(password)) {
      score += 1;
    }

    return PasswordStrength(
      score: score,
      feedback: feedback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strength = _calculateStrength();

    final strengthLabels = ['Muito fraca', 'Fraca', 'Regular', 'Boa', 'Forte'];
    final strengthColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow[700]!,
      Colors.blue,
      Colors.green,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark 
                      ? const Color(0xFF334155) 
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: strength.score / 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: strengthColors[strength.score],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strengthLabels[strength.score],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: strengthColors[strength.score],
              ),
            ),
          ],
        ),
        if (strength.feedback.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Faltam: ${strength.feedback.join(', ')}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            'Senha forte!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class PasswordStrength {
  final int score;
  final List<String> feedback;

  PasswordStrength({
    required this.score,
    required this.feedback,
  });
}
