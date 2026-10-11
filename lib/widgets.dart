import 'package:flutter/material.dart';

import 'theme.dart';

/// خلفية متدرجة مع هالات ضوء ناعمة.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.bgTop, p.bg],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _Glow(color: p.glow, size: 280)),
          Positioned(bottom: -120, left: -90, child: _Glow(color: p.glow, size: 320)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, const Color(0x00000000)]),
        ),
      ),
    );
  }
}

/// بطاقة زجاجية بحواف ناعمة.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

/// زر بتدرج لوني.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: Pal.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x551C9BFF),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// شكل موحد لحقول الإدخال.
InputDecoration inputDeco(
  BuildContext context, {
  String? label,
  String? hint,
  IconData? icon,
}) {
  final p = Pal.of(context);
  OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: p.textDim),
    filled: true,
    fillColor: p.field,
    labelStyle: TextStyle(color: p.textDim),
    hintStyle: TextStyle(color: p.textDim),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: b(p.border, 1),
    enabledBorder: b(p.border, 1),
    focusedBorder: b(Pal.accent, 1.6),
    counterText: '',
  );
}
