import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/theme.dart';

/// Pill-shaped search input with a leading search icon and a clear button.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String initialValue;
  final bool autofocus;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyMedium,
      onChanged: (value) {
        widget.onChanged(value);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        fillColor: AppColors.surfaceTranslucent,
        prefixIcon: const Icon(
          LucideIcons.search,
          size: AppSizes.iconMd,
          color: AppColors.textMuted,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _clear,
                icon: const Icon(
                  LucideIcons.x,
                  size: AppSizes.iconSm,
                  color: AppColors.textMuted,
                ),
              ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: AppColors.surface),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: AppColors.surface),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.pillAll,
          borderSide: BorderSide(color: AppColors.midnight),
        ),
      ),
    );
  }
}
