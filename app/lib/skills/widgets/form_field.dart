// Personal Skills UI — form field widget

import 'package:flutter/material.dart';

/// A labeled form field with optional validation
class SkillFormField extends StatefulWidget {
  const SkillFormField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.initialValue,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? initialValue;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  @override
  State<SkillFormField> createState() => _SkillFormFieldState();
}

class _SkillFormFieldState extends State<SkillFormField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SkillFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.controller == null) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: widget.validator,
        ),
      ],
    );
  }
}