// Tool Binding Dropdown — select tool for tool-mode steps
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// Dropdown to pick tool for tool-mode steps
class ToolBindingDropdown extends StatelessWidget {
  const ToolBindingDropdown({
    super.key,
    required this.tool,
    required this.onToolChanged,
    this.enabled = true,
    this.label = 'Tool',
  });

  final String? tool;
  final ValueChanged<String?> onToolChanged;
  final bool enabled;
  final String label;

  static const List<ToolOption> availableTools = [
    ToolOption(name: 'bash', label: 'Bash', description: 'Run shell commands', iconCodePoint: 0xe047), // Icons.terminal
    ToolOption(name: 'edit', label: 'Edit', description: 'Edit files', iconCodePoint: 0xe3c9), // Icons.edit
    ToolOption(name: 'write', label: 'Write', description: 'Write files', iconCodePoint: 0xe15d), // Icons.note_add
    ToolOption(name: 'read', label: 'Read', description: 'Read files', iconCodePoint: 0xe15c), // Icons.note
    ToolOption(name: 'web_fetch', label: 'Web Fetch', description: 'Fetch web pages', iconCodePoint: 0xe8c0), // Icons.web
    ToolOption(name: 'web_search', label: 'Web Search', description: 'Search the web', iconCodePoint: 0xe8b6), // Icons.search
    ToolOption(name: 'present', label: 'Present', description: 'Present files', iconCodePoint: 0xe0e1), // Icons.present_to_all
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: tool,
          isExpanded: true,
          hint: Text(l10n.skillsToolBindingHint),
          onChanged: enabled ? (v) => onToolChanged(v) : null,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('(none)'),
            ),
            ...availableTools.map((t) => DropdownMenuItem<String>(
              value: t.name,
              child: Row(
                children: [
                  Icon(IconData(t.iconCodePoint, fontFamily: 'MaterialIcons'), size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          t.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class ToolOption {
  const ToolOption({
    required this.name,
    required this.label,
    required this.description,
    required this.iconCodePoint,
  });

  final String name;
  final String label;
  final String description;
  final int iconCodePoint;
}