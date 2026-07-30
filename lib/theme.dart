import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// LocalHive design system — Apple Human Interface inspired.
/// Palette follows Apple's classic neutrals with iOS system accents.
class LhColors {
  static const ink = Color(0xFF1D1D1F); // primary text (Apple near-black)
  static const inkSecondary = Color(0xFF6E6E73); // secondary text
  static const navy = Color(0xFF0A2540); // primary brand / CTAs
  static const blue = Color(0xFF0071E3); // Apple action blue
  static const background = Color(0xFFF5F5F7); // Apple light gray
  static const surface = Colors.white;
  static const hairline = Color(0xFFD2D2D7);
  static const green = Color(0xFF34C759); // iOS system green
  static const orange = Color(0xFFFF9500); // iOS system orange
  static const indigo = Color(0xFF5856D6); // iOS system indigo
  static const amber = Color(0xFFFFB300);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: LhColors.navy,
      onPrimary: Colors.white,
      secondary: LhColors.blue,
      onSecondary: Colors.white,
      surface: LhColors.surface,
      onSurface: LhColors.ink,
      outline: LhColors.inkSecondary,
      outlineVariant: LhColors.hairline,
    ),
    scaffoldBackgroundColor: LhColors.background,
  );

  final text = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: LhColors.ink,
    displayColor: LhColors.ink,
  );

  return base.copyWith(
    textTheme: text,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: LhColors.background,
      foregroundColor: LhColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: LhColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: LhColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LhColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LhColors.blue,
        side: const BorderSide(color: LhColors.hairline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LhColors.blue,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: LhColors.surface,
      selectedColor: LhColors.navy,
      labelStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: LhColors.ink),
      secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      side: const BorderSide(color: LhColors.hairline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LhColors.surface.withValues(alpha: 0.94),
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? LhColors.blue
              : LhColors.inkSecondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? LhColors.blue
              : LhColors.inkSecondary,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
        color: LhColors.hairline, thickness: 0.5, space: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFEBEBED),
      hintStyle: GoogleFonts.inter(color: LhColors.inkSecondary, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    ),
  );
}

/// iOS Settings-style rounded icon tile.
/// The app-wide FilledButton theme sets `minimumSize: Size.fromHeight(50)`,
/// which means an *infinite* minimum width. That is right for full-width CTAs
/// but makes the button unlayoutable anywhere the width is bounded (a Row, a
/// ListTile trailing slot). Use this style for those inline buttons.
ButtonStyle compactButtonStyle({double width = 66, double height = 34}) =>
    FilledButton.styleFrom(
      backgroundColor: LhColors.navy,
      foregroundColor: Colors.white,
      minimumSize: Size(width, height),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    );

/// Style for a FilledButton in an AlertDialog's action row. Without it the
/// theme's infinite minimum width overflows the dialog's OverflowBar, which
/// then stacks Cancel above the confirm button instead of placing them side by
/// side.
ButtonStyle dialogButtonStyle({Color? background}) => FilledButton.styleFrom(
      backgroundColor: background ?? LhColors.navy,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconTile(
      {super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.55),
    );
  }
}

/// Apple-style grouped inset section.
class InsetGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  const InsetGroup({super.key, required this.children, this.header});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(header!.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LhColors.inkSecondary,
                    letterSpacing: 0.3)),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Padding(
                      padding: EdgeInsets.only(left: 60), child: Divider()),
              ]
            ],
          ),
        ),
      ],
    );
  }
}
