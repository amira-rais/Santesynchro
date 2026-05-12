import 'package:flutter/material.dart';
import 'package:frontend/core/app_localizations.dart';

class PasswordValidationWidget extends StatelessWidget {
  final String password;
  final bool isVisible;
  final Function(bool isValid3of4) onValidationChanged;

  const PasswordValidationWidget({
    super.key,
    required this.password,
    required this.isVisible,
    required this.onValidationChanged,
  });

  bool get hasMinLength => password.length >= 7;
  bool get hasMixedCase => password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]'));
  bool get hasDigit => password.contains(RegExp(r'[0-9]'));
  bool get hasSpecialChar => password.contains(RegExp(r'[#&@_!*$%.]'));

  bool get isValid3of4 {
    int count = 0;
    if (hasMinLength) count++;
    if (hasMixedCase) count++;
    if (hasDigit) count++;
    if (hasSpecialChar) count++;
    return count >= 3;
  }

  @override
  Widget build(BuildContext context) {
    // Notify parent about validation status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onValidationChanged(isValid3of4);
    });

    return Visibility(
      visible: isVisible,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildConditionItem(AppLocalizations.of(context).translate('pwd_min_length'), hasMinLength),
          _buildConditionItem(AppLocalizations.of(context).translate('pwd_mixed_case'), hasMixedCase),
          _buildConditionItem(AppLocalizations.of(context).translate('pwd_digit'), hasDigit),
          _buildConditionItem(AppLocalizations.of(context).translate('pwd_special'), hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildConditionItem(String label, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.circle,
            color: isValid ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isValid ? Colors.green : Colors.red,
              fontSize: 12,
              fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
