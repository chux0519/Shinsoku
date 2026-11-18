import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// DESIGN §5 text input. Label above the field (not floating), a frame fill
/// instead of an outline; focus shows a thin accent edge. Single-line fields
/// use `maxLines: 1` (see [SkTextArea.field]).
class SkTextArea extends StatelessWidget {
  const SkTextArea({
    required this.controller,
    this.label,
    this.placeholder,
    this.helper,
    this.fieldKey,
    this.minLines = 3,
    this.maxLines,
    this.expands = false,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = true,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.trailing,
    this.style,
    this.textAlign = TextAlign.start,
    this.onSubmitted,
    super.key,
  });

  /// A single-line field (URLs, keys, model names).
  const SkTextArea.field({
    required this.controller,
    this.label,
    this.placeholder,
    this.helper,
    this.fieldKey,
    this.autofocus = false,
    this.enabled = true,
    this.obscureText = false,
    this.autocorrect = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.trailing,
    this.style,
    this.textAlign = TextAlign.start,
    this.onSubmitted,
    super.key,
  }) : minLines = 1,
       maxLines = 1,
       expands = false;

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final String? helper;

  /// Key for the inner TextField (tests drive it with enterText).
  final Key? fieldKey;
  final int? minLines;
  final int? maxLines;

  /// Fill the parent's height (editor screens).
  final bool expands;
  final bool autofocus;
  final bool enabled;
  final bool obscureText;
  final bool autocorrect;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Widget? trailing;

  /// Overrides the body style (e.g. transcript, or a large mono code).
  final TextStyle? style;
  final TextAlign textAlign;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = SkColors.of(context);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(SkShape.control),
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
    final field = TextField(
      key: fieldKey,
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: !obscureText && autocorrect,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      minLines: expands ? null : minLines,
      maxLines: expands ? null : maxLines,
      expands: expands,
      textAlign: textAlign,
      textAlignVertical: expands ? TextAlignVertical.top : null,
      onSubmitted: onSubmitted,
      style: (style ?? SkType.body).copyWith(
        color: enabled ? c.text : c.textTertiary,
      ),
      cursorColor: c.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: c.frame,
        hintText: placeholder,
        hintStyle: (style ?? SkType.body).copyWith(color: c.textTertiary),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SkSpace.m,
          vertical: SkSpace.m,
        ),
        suffixIcon: trailing,
        suffixIconConstraints: const BoxConstraints(
          minWidth: SkShape.minTarget,
          minHeight: SkShape.minTarget,
        ),
        border: border(c.border, 0),
        enabledBorder: border(c.border, 0),
        disabledBorder: border(c.border, 0),
        focusedBorder: border(c.accent, 1.5),
      ),
    );
    if (label == null && helper == null) {
      return field;
    }
    final labelled = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!,
              style: SkType.secondary.copyWith(color: c.textSecondary),
            ),
          ),
        if (expands) Expanded(child: field) else field,
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: SkType.caption.copyWith(color: c.textSecondary),
            ),
          ),
      ],
    );
    // The visible label doubles as the field's accessible name.
    return label == null
        ? labelled
        : Semantics(label: label, container: true, child: labelled);
  }
}
