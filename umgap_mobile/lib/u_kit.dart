import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════
//  UMGAP DESIGN SYSTEM — u_kit.dart
//  Single source of truth. Jangan definisikan warna/spacing di tempat lain.
// ════════════════════════════════════════════════════════════════════

// ─── COLOR TOKENS ───────────────────────────────────────────────────
class UColors {
  // Brand
  static const navy        = Color(0xFF0B1733);
  static const navyMid     = Color(0xFF14275C);
  static const primary     = Color(0xFF1565C0);
  static const primaryMid  = Color(0xFF1E88E5);
  static const primaryLight= Color(0xFF42A5F5);
  static const primaryDark = Color(0xFF0D47A1);
  static const cyan        = Color(0xFF29B6F6);
  static const accent      = Color(0xFF00B0FF); // ← tetap ada agar tidak breaking

  // Semantic
  static const success     = Color(0xFF2E7D32);
  static const successLight= Color(0xFFE8F5E9);
  static const warning     = Color(0xFFE65100);
  static const warningLight= Color(0xFFFFF3E0);
  static const danger      = Color(0xFFC62828);
  static const dangerLight = Color(0xFFFFEBEE);
  static const info        = Color(0xFF0277BD);
  static const infoLight   = Color(0xFFE3F2FD);
  static const purple      = Color(0xFF6A1B9A);
  static const purpleLight = Color(0xFFF3E5F5);
  static const amber       = Color(0xFFD97706);
  static const amberLight  = Color(0xFFFFF8E1);
  static const teal        = Color(0xFF00838F);
  static const tealLight   = Color(0xFFE0F7FA);

  // Surface
  static const surface     = Color(0xFFF2F5FC);
  static const surfaceMid  = Color(0xFFE8EDF7);
  static const card        = Color(0xFFFFFFFF);
  static const inputBg     = Color(0xFFF0F4FF);

  // Text
  static const textDark    = Color(0xFF0D1B3E);
  static const textMid     = Color(0xFF4A5568);
  static const textSoft    = Color(0xFF8FA3BF);
  static const textLight   = Color(0xFFB0C4DE);

  // Utility
  static const divider     = Color(0xFFEDF2FB);
  static const overlay     = Color(0x0F1565C0); // 6% primary
}

// ─── SPACING TOKENS (8px grid) ──────────────────────────────────────
class USpace {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double base= 16;
  static const double lg  = 20;
  static const double xl  = 24;
  static const double x2l = 32;
  static const double x3l = 48;
}

// ─── RADIUS TOKENS ──────────────────────────────────────────────────
class URadius {
  static const double xs  = 6;
  static const double sm  = 10;
  static const double md  = 14;
  static const double lg  = 18;
  static const double xl  = 22;
  static const double x2l = 28;
  static const double full= 999;
}

// ─── SHADOW TOKENS ──────────────────────────────────────────────────
class UShadow {
  static List<BoxShadow> sm(Color color) => [
    BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> md(Color color) => [
    BoxShadow(color: color.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> lg(Color color) => [
    BoxShadow(color: color.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 3)),
  ];
}

// ─── TYPOGRAPHY ──────────────────────────────────────────────────────
class UText {
  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: UColors.textDark, letterSpacing: -0.5, height: 1.2);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: UColors.textDark, letterSpacing: -0.3);
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: UColors.textDark);
  static const h4 = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: UColors.textDark);
  static const h5 = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: UColors.textDark);

  static const body  = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: UColors.textMid, height: 1.6);
  static const bodyS = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: UColors.textMid, height: 1.5);
  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UColors.textSoft);
  static const label  = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: UColors.textSoft, letterSpacing: 0.5);
}

// ════════════════════════════════════════════════════════════════════
//  LOGO
// ════════════════════════════════════════════════════════════════════
class UmgapLogo extends StatelessWidget {
  final double size;
  const UmgapLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo/UMGAP (2).png',
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _LogoFallback(size: size),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final double size;
  const _LogoFallback({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [UColors.primaryDark, UColors.primaryMid],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Text('UM',
        style: TextStyle(color: Colors.white, fontSize: size * 0.32,
            fontWeight: FontWeight.w900, letterSpacing: size * 0.04))),
  );
}

// ════════════════════════════════════════════════════════════════════
//  HEADER — gradient navy dengan rounded bottom
// ════════════════════════════════════════════════════════════════════
class UHeader extends StatelessWidget {
  final Widget child;
  final double bottomRadius;

  const UHeader({super.key, required this.child, this.bottomRadius = URadius.x2l});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UColors.navy, UColors.navyMid, UColors.primary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  APP BAR — PreferredSizeWidget untuk Scaffold.appBar
// ════════════════════════════════════════════════════════════════════
class UAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final PreferredSizeWidget? bottom;
  final VoidCallback? onBack;

  const UAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.bottom,
    this.onBack,
  });

  @override
  Size get preferredSize => Size.fromHeight(bottom != null ? 56 + 48 : 56);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [UColors.primaryDark, UColors.primary, UColors.primaryMid],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
          title: Text(title, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700,
            fontSize: 18, letterSpacing: 0.2,
          )),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: showBack,
          leading: showBack
              ? IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: onBack ?? () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
          )
              : null,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          actions: actions,
          bottom: bottom,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BACK BUTTON — konsisten di semua header custom
// ════════════════════════════════════════════════════════════════════
class UBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  const UBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      if (onTap != null) { onTap!(); } else { Navigator.pop(context); }
    },
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(URadius.sm),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: const Icon(Icons.arrow_back_ios_new_rounded,
          color: Colors.white, size: 16),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  CARD
// ════════════════════════════════════════════════════════════════════
class UCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? accentColor;    // left accent bar
  final VoidCallback? onTap;
  final double? radius;

  const UCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.onTap,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final r = radius ?? URadius.lg;
    Widget card = Container(
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(r),
        boxShadow: UShadow.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: accentColor != null
            ? IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: accentColor),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(USpace.base),
                child: child,
              ),
            ),
          ]),
        )
            : Padding(
          padding: padding ?? const EdgeInsets.all(USpace.base),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap!(); },
        child: card,
      );
    }
    return card;
  }
}

// ─── Card dengan header section ──────────────────────────────────────
class USectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailing;

  const USectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? UColors.primary;
    return UCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(USpace.base, USpace.md, USpace.base, USpace.md),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(URadius.xs),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: USpace.sm),
            Expanded(child: Text(title, style: UText.h5)),
            if (trailing != null) trailing!,
          ]),
        ),
        Divider(height: 1, color: UColors.divider),
        Padding(
          padding: const EdgeInsets.all(USpace.base),
          child: child,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BUTTON — backward compatible: outlined sebagai bool parameter
// ════════════════════════════════════════════════════════════════════
class UButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool outlined;   // ← bool, sama seperti sebelumnya
  final Color? color;
  final double height;

  const UButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.color,
    this.outlined = false,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    final disabled  = onPressed == null || loading;
    final baseColor = color ?? UColors.primary;

    return GestureDetector(
      onTap: disabled ? null : () {
        HapticFeedback.mediumImpact();
        onPressed!();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          gradient: outlined || disabled
              ? null
              : LinearGradient(
            colors: [
              color != null ? color!.withOpacity(0.85) : UColors.primaryDark,
              color ?? UColors.primaryMid,
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          color: outlined
              ? Colors.transparent
              : disabled ? const Color(0xFFCFD8DC) : null,
          borderRadius: BorderRadius.circular(URadius.md),
          border: outlined
              ? Border.all(
              color: disabled ? UColors.textLight : baseColor, width: 1.5)
              : null,
          boxShadow: (!outlined && !disabled) ? UShadow.lg(baseColor) : null,
        ),
        child: Center(
          child: loading
              ? SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(
                  color: outlined ? baseColor : Colors.white,
                  strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, color: outlined ? baseColor : Colors.white, size: 18),
              const SizedBox(width: USpace.sm),
            ],
            Text(label, style: TextStyle(
              color:      outlined
                  ? (disabled ? UColors.textLight : baseColor)
                  : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize:   15,
              letterSpacing: 0.3,
            )),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TEXT FIELD
// ════════════════════════════════════════════════════════════════════
class UField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final int maxLines;
  final TextInputType? keyboard;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool readOnly;

  const UField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.maxLines = 1,
    this.keyboard,
    this.prefixIcon,
    this.suffixWidget,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: UText.label.copyWith(color: UColors.textMid)),
      const SizedBox(height: USpace.xs + 2),
      TextField(
        controller:    controller,
        obscureText:   obscure,
        maxLines:      obscure ? 1 : maxLines,
        keyboardType:  keyboard,
        onChanged:     onChanged,
        onSubmitted:   onSubmitted,
        readOnly:      readOnly,
        style: const TextStyle(fontSize: 14, color: UColors.textDark, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText:      hint,
          hintStyle:     UText.caption.copyWith(color: UColors.textLight),
          prefixIcon:    prefixIcon != null
              ? Icon(prefixIcon, color: UColors.primary, size: 18) : null,
          suffix:        suffixWidget,
          filled:        true,
          fillColor:     UColors.inputBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: USpace.base, vertical: USpace.md),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: BorderSide(color: UColors.primary.withOpacity(0.15))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(URadius.md),
              borderSide: const BorderSide(color: UColors.primaryMid, width: 1.5)),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  BADGE — status chips
// ════════════════════════════════════════════════════════════════════
class UBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const UBadge(this.label, {super.key, this.color});

  static Color _auto(String s) {
    final u = s.toUpperCase();
    if (u.contains('ONTIME') || u.contains('APPROVED') || u.contains('PRESENT') || u.contains('ACTIVE')) return UColors.success;
    if (u.contains('LATE')   || u.contains('SICK'))   return UColors.warning;
    if (u.contains('ABSENT') || u.contains('REJECTED') || u.contains('INACTIVE')) return UColors.danger;
    if (u.contains('LEAVE')  || u.contains('TRANSFER')) return UColors.info;
    if (u.contains('PENDING')) return UColors.purple;
    if (u.contains('ADMIN'))   return UColors.primaryDark;
    return UColors.textSoft;
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? _auto(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:  c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(URadius.full),
        border: Border.all(color: c.withOpacity(0.28)),
      ),
      child: Text(label, style: TextStyle(
          color: c, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  INFO ROW — key: value
// ════════════════════════════════════════════════════════════════════
class UInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool showDivider;

  const UInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: UColors.primary.withOpacity(0.5)),
            const SizedBox(width: USpace.sm),
          ],
          SizedBox(
            width: 110,
            child: Text(label, style: UText.bodyS.copyWith(color: UColors.textSoft)),
          ),
          Expanded(child: Text(value,
              style: UText.bodyS.copyWith(
                  color: UColors.textDark, fontWeight: FontWeight.w700))),
        ]),
      ),
      if (showDivider)
        Divider(height: 1, color: UColors.divider),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  SECTION HEADER
// ════════════════════════════════════════════════════════════════════
class USectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const USectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [UColors.primaryDark, UColors.cyan],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: UText.h5)),
      if (trailing != null) trailing!,
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ════════════════════════════════════════════════════════════════════
class UEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const UEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(USpace.x2l),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(USpace.xl),
            decoration: BoxDecoration(
              color: UColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: UColors.primary.withOpacity(0.25)),
          ),
          const SizedBox(height: USpace.base),
          Text(title, style: UText.h5, textAlign: TextAlign.center),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: USpace.xs),
            Text(subtitle, style: UText.bodyS, textAlign: TextAlign.center),
          ],
          if (action != null) ...[
            const SizedBox(height: USpace.base),
            action!,
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STAT CARD
// ════════════════════════════════════════════════════════════════════
class UStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const UStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(USpace.base),
      decoration: BoxDecoration(
        color: UColors.card,
        borderRadius: BorderRadius.circular(URadius.lg),
        boxShadow: UShadow.md(color),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(URadius.sm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: USpace.sm),
        Text(value, style: UText.h2.copyWith(color: color,
            fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 2),
        Text(title, style: UText.caption),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  INFO BOX — tip / warning / info
// ════════════════════════════════════════════════════════════════════
enum UInfoBoxVariant { tip, warning, info, error }

class UInfoBox extends StatelessWidget {
  final String message;
  final UInfoBoxVariant variant;
  final IconData? icon;

  const UInfoBox(this.message, {
    super.key,
    this.variant = UInfoBoxVariant.info,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final config = {
      UInfoBoxVariant.tip:     (UColors.success, UColors.successLight, Icons.lightbulb_outline_rounded),
      UInfoBoxVariant.warning: (UColors.warning, UColors.warningLight, Icons.warning_amber_rounded),
      UInfoBoxVariant.info:    (UColors.info,    UColors.infoLight,    Icons.info_outline_rounded),
      UInfoBoxVariant.error:   (UColors.danger,  UColors.dangerLight,  Icons.error_outline_rounded),
    }[variant]!;

    return Container(
      padding: const EdgeInsets.all(USpace.md),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(URadius.sm),
        border: Border.all(color: config.$1.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon ?? config.$3, color: config.$1, size: 16),
        const SizedBox(width: USpace.sm),
        Expanded(child: Text(message,
            style: UText.bodyS.copyWith(color: config.$1, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HEADER ICON BUTTON — untuk button di pojok header
// ════════════════════════════════════════════════════════════════════
class UHeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;

  const UHeaderIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Stack(clipBehavior: Clip.none, children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(URadius.sm),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      if (badge != null)
        Positioned(top: -5, right: -5,
          child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: UColors.danger, shape: BoxShape.circle),
            child: Center(child: Text(badge!, style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
          ),
        ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════
//  LOADING OVERLAY
// ════════════════════════════════════════════════════════════════════
class ULoadingOverlay extends StatelessWidget {
  final bool loading;
  final Widget child;

  const ULoadingOverlay({super.key, required this.loading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      if (loading)
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0x55000000),
            child: Center(child: CircularProgressIndicator(
                color: UColors.primaryLight, strokeWidth: 2.5)),
          ),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  GLASS PILL — untuk header chips
// ════════════════════════════════════════════════════════════════════
class UGlassPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accentColor;

  const UGlassPill({super.key, required this.icon, required this.label, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(URadius.full),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: USpace.xs + 2),
        Text(label, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════

// Page transition — fade + slide
PageRoute uRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0), end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

// Snack bar
void uSnack(BuildContext context, String msg, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? UColors.danger : UColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(URadius.sm)),
      margin: const EdgeInsets.all(USpace.base),
      duration: const Duration(seconds: 3),
    ));
}

// Format rupiah
String uRupiah(dynamic v) {
  final n = (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
  if (n == 0) return 'Rp -';
  return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
}

// Initials dari nama
String uInitials(String name) {
  final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}