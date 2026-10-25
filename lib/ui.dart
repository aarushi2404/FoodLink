import 'package:flutter/material.dart';

// Brand colours (same palette as the project deck).
const kCoral = Color(0xFFE5484D);
const kNavy = Color(0xFF2F3C7E);
const kGreen = Color(0xFF3FA66A);

/// Material 3 theme, light + dark, built from the brand colours.
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: kCoral, brightness: brightness);
  final scheme = dark
      ? base.copyWith(
          primary: const Color(0xFFFF8A8E),
          onPrimary: const Color(0xFF5C0A12),
        )
      : base.copyWith(
          primary: kCoral,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFE3E1),
          onPrimaryContainer: const Color(0xFF410006),
          surface: const Color(0xFFFFFBF9),
        );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
  );
}

/// Outlined text-field decoration used on every form.
InputDecoration fieldDeco(String label,
    {String? hint, String? helper, IconData? icon, Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    errorMaxLines: 2,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}

LinearGradient headerGradient(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? const [Color(0xFF8E2A31), Color(0xFF5A2D4F)]
        : const [Color(0xFFE5484D), Color(0xFFF58A5C)],
  );
}

/// Coloured header with rounded bottom corners, used at the top of every
/// main screen (replaces the plain AppBar).
class GradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 14, 12, 18),
      decoration: BoxDecoration(
        gradient: headerGradient(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 12),
            bottom!,
          ],
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
    );
  }
}

/// Round initial that opens a small account menu (sign out).
class AvatarMenu extends StatelessWidget {
  final String name;
  final VoidCallback onSignOut;
  const AvatarMenu({super.key, required this.name, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (_) => onSignOut(),
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 20),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.25),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded, softly outlined container used instead of the stock Card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = EdgeInsets.zero,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin ?? const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color ?? scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. "Live" or "Collected".
class InfoPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  const InfoPill({
    super.key,
    required this.text,
    this.icon,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSecondaryContainer;
    final bg = background ?? scheme.secondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Indian-style veg / non-veg marker.
class VegBadge extends StatelessWidget {
  final bool isVeg;
  const VegBadge({super.key, required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final c = isVeg ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: c, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Icon, label, emoji and tint for each kind of vendor.
class TypeStyle {
  final IconData icon;
  final String label;
  final String emoji;
  final Color color;
  const TypeStyle(this.icon, this.label, this.emoji, this.color);
}

TypeStyle typeStyle(String type) {
  switch (type) {
    case 'restaurant':
      return const TypeStyle(Icons.restaurant_menu, 'Restaurant', '🍛', Color(0xFFE67E22));
    case 'bakery':
      return const TypeStyle(Icons.bakery_dining, 'Bakery', '🥐', Color(0xFFC0843D));
    case 'dairy':
      return const TypeStyle(Icons.icecream, 'Dairy', '🥛', Color(0xFF3B8EDB));
    default:
      return const TypeStyle(Icons.school, 'Canteen', '🍱', Color(0xFF8E5BD0));
  }
}
