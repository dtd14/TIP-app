import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tip_app/app/theme/app_text_styles.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.validator,
    this.serverError,
    this.hint,
    this.password = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.inputFormatters,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final String? serverError;
  final String? hint;
  final bool password;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          validator: widget.validator,
          onChanged: widget.onChanged,
          obscureText: widget.password && _obscure,
          autocorrect: !widget.password,
          enableSuggestions: !widget.password,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          onFieldSubmitted: (value) {
            if (widget.textInputAction == TextInputAction.next) {
              FocusScope.of(context).nextFocus();
            }
            widget.onSubmitted?.call(value);
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            errorText: widget.serverError,
            prefixIcon: Icon(widget.icon, size: 21),
            suffixIcon: widget.password
                ? IconButton(
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: widget.enabled
                        ? () => setState(() => _obscure = !_obscure)
                        : null,
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  )
                : null,
          ),
        ),
      ],
    ),
  );
}
