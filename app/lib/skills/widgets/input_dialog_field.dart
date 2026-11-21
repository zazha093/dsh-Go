// Personal Skills UI — input dialog field widget

import 'package:flutter/material.dart';

/// A text form field for the input dialog
class SkillInputDialogField extends StatelessWidget {
  const SkillInputDialogField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}