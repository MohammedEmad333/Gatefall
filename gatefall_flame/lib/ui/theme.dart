import 'package:flutter/material.dart';

import '../audio/sfx.dart';

/// The one palette. Night, rift-violet, and the three currencies each with
/// their own colour so a number's meaning reads before you read the number:
/// mana is verdant, gold is gold, bond is rose.
const night = Color(0xFF0D0B1A);
const night2 = Color(0xFF151129);
const rift = Color(0xFF6B4BD6);
const riftDim = Color(0xFF3A2B73);
const verdant = Color(0xFF5FD39A);
const bone = Color(0xFFE8E4F0);
const boneDim = Color(0xFF9B93B5);
const blood = Color(0xFFD4536B);
const gold = Color(0xFFE0B95F);
const rose = Color(0xFFE07FA8);

ThemeData gatefallTheme() => ThemeData(
      scaffoldBackgroundColor: night,
      colorScheme: const ColorScheme.dark(primary: rift, surface: night2),
      fontFamily: 'Georgia',
      useMaterial3: true,
    );

/// The bordered slab every screen is built out of.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(13),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? riftDim),
          color: Colors.black.withValues(alpha: .2),
        ),
        child: child,
      );
}

class PanelTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PanelTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: bone, fontSize: 14)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!,
                style: const TextStyle(
                    color: boneDim,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ],
        ],
      );
}

/// A left-bordered callout. [tone] picks the colour: gold for a warning the
/// player chose, blood for a real disadvantage, verdant for good news.
class Callout extends StatelessWidget {
  final String text;
  final Color tone;

  const Callout(this.text, {super.key, this.tone = gold});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: tone, width: 2)),
          color: tone.withValues(alpha: .07),
        ),
        child: Text(text,
            style: TextStyle(color: tone, fontSize: 11.5, height: 1.5)),
      );
}

class Bar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const Bar(this.fraction, this.color, {super.key, this.height = 7});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: fraction.clamp(0, 1),
          minHeight: height,
          backgroundColor: Colors.white.withValues(alpha: .07),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      );
}

/// The square-cornered button this game uses everywhere.
///
/// Version 3: this is also where the interface got its voice. Every button
/// in the game is one of these, so wiring the tap sound in here — rather
/// than at two dozen call sites — means nothing can be silent by omission.
class SlabButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color tone;
  final bool filled;
  final EdgeInsetsGeometry padding;

  /// The sound this button makes. A destructive or backward action passes
  /// something else; the default is the neutral tap.
  final Sfx sound;

  const SlabButton(
    this.label, {
    super.key,
    this.onPressed,
    this.tone = rift,
    this.filled = false,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    this.sound = Sfx.uiSelect,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final press = onPressed == null
        ? null
        : () {
            Audio.instance.noteGesture();
            Audio.instance.play(sound);
            onPressed!();
          };
    if (filled) {
      return FilledButton(
        onPressed: press,
        style: FilledButton.styleFrom(
          backgroundColor: tone,
          disabledBackgroundColor: riftDim.withValues(alpha: .4),
          padding: padding,
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }
    return OutlinedButton(
      onPressed: press,
      style: OutlinedButton.styleFrom(
        foregroundColor: enabled ? tone : boneDim,
        side: BorderSide(color: enabled ? tone : riftDim),
        padding: padding,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Mana / Gold / Bond readout. Monospace so the digits don't jitter.
class CurrencyChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const CurrencyChip(this.value, this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontFamily: 'monospace')),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color.withValues(alpha: .7), fontSize: 11)),
        ],
      );
}

/// A screen's title row: a title that gives ground before the readout does.
/// Every screen used to hand-roll this as a bare `Row`, which overflowed on
/// a narrow phone as soon as the number beside it grew a digit.
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const ScreenHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: bone, fontSize: 16)),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      );
}

/// The screen-width column every screen sits in, so a desktop browser gets a
/// phone-shaped column rather than a stretched mess.
class ScreenBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const ScreenBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 28),
  });

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: ListView(padding: padding, children: children),
        ),
      );
}
