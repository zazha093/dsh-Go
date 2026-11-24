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
  };

  final String? tool;
  final ValueChanged<String?> onToolChanged;
  final bool enabled;
  final String label;

  static const List<_ToolOption> availableTools = [
    _ToolOption(name: 'bash', label: 'Bash', description: 'Run shell commands', icon: Icons.terminal),
    _ToolOption(name: 'edit', label: 'Edit', description: 'Edit files', icon: Icons.edit),
    _ToolOption(name: 'write', label: 'Write', description: 'Write files', icon: Icons.note_add),
    _ToolOption(name: 'read', label: 'Read', description: 'Read files', icon: Icons.note),
    _ToolOption(name: 'web_fetch', label: 'Web Fetch', description: 'Fetch web pages', icon: Icons.web),
    _ToolOption(name: 'web_search', label: 'Web Search', description: 'Search the web', icon: Icons.search),
    _ToolOption(name: 'present', label: 'Present', description: 'Present files', icon: Icons.present_to_all),
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
                  Icon(t.icon, size: 20, color: Theme.of(context).colorScheme.primary),
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

class _ToolOption {
  const _ToolOption({
    required this.name,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String name;
  final String label;
  final String description;
  final IconData icon;
}