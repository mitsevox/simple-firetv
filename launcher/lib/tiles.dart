import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'apps.dart';
import 'brands.dart';
import 'style.dart';

// Dock tiles are logo-only. The mark centre must match MARK_CENTER_Y in tool/marks.py.
const dockTileWidth = 224.0;
const dockTileHeight = 176.0;
const _dockMarkCenter = Offset(dockTileWidth / 2, 88);

// All apps tiles keep names, since apps without a mark need them.
const gridTileWidth = 288.0;
const gridTileHeight = 232.0;
const _gridMarkCenter = Offset(gridTileWidth / 2, 74);

const _nativeIconSize = 64.0;

/// A logo-only app in the dock.
class DockTile extends StatelessWidget {
  const DockTile({super.key, required this.app, required this.focused});

  final AppInfo app;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dockTileWidth,
      height: dockTileHeight,
      child: _Focusable(
        focused: focused,
        plate: const Rect.fromLTWH(0, 16, dockTileWidth, 144),
        builder: (t) => [_mark(app, _dockMarkCenter, t)],
      ),
    );
  }
}

/// An app in the All apps grid: its mark over its name.
class AllAppsTile extends StatelessWidget {
  const AllAppsTile({super.key, required this.app, required this.focused, required this.onHome});

  final AppInfo app;
  final bool focused;

  /// Shows a check for apps that are on the dock.
  final bool onHome;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: gridTileWidth,
      height: gridTileHeight,
      child: _Focusable(
        focused: focused,
        plate: const Rect.fromLTWH(0, 16, gridTileWidth, 200),
        builder: (t) => [
          _mark(app, _gridMarkCenter, t),
          Positioned(
            left: 4,
            right: 4,
            top: 128,
            child: Text(
              displayName(app.package, app.label),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type(36, spacing: -.8, color: _ink(t), shadows: softShadow),
            ),
          ),
          if (onHome)
            Positioned(
              right: 20,
              top: 32,
              child: Icon(Icons.check_circle, size: 30, color: ink.withValues(alpha: .9)),
            ),
        ],
      ),
    );
  }
}

Color _ink(double t) => ink.withValues(alpha: .84 + .16 * t);

/// Places an app's mark as tool/marks.py laid it out: its box centred on [center], then moved
/// down by the mark's optical offset. [t] runs 0 → 1 as the tile gains focus.
Widget _mark(AppInfo app, Offset center, double t) {
  final brand = brands[app.package];
  final layout = brand?.layout ?? (width: _nativeIconSize, height: _nativeIconSize, dy: 0.0);
  final size = Size(layout.width, layout.height);
  final Widget mark = brand != null
      ? SvgPicture.asset(
          brand.asset,
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          colorFilter: ColorFilter.mode(_ink(t), BlendMode.srcIn),
        )
      : ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            app.icon,
            width: size.width,
            height: size.height,
            filterQuality: FilterQuality.medium,
            color: Colors.white.withValues(alpha: .84 + .16 * t),
            colorBlendMode: BlendMode.modulate,
          ),
        );
  return Positioned(
    left: center.dx - size.width / 2,
    top: center.dy + layout.dy - size.height / 2,
    width: size.width,
    height: size.height,
    child: Transform.scale(scale: 1 + .06 * t, child: mark),
  );
}

/// The frosted plate behind a focused tile, plus an eased 0 → 1 focus value for its contents.
class _Focusable extends StatelessWidget {
  const _Focusable({required this.focused, required this.plate, required this.builder});

  final bool focused;
  final Rect plate;
  final List<Widget> Function(double t) builder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fromRect(
          rect: plate,
          child: AnimatedOpacity(
            opacity: focused ? 1 : 0,
            duration: fadeDuration,
            child: DecoratedBox(decoration: plate32),
          ),
        ),
        Positioned.fill(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: focused ? 1 : 0),
            duration: moveDuration,
            curve: ease,
            builder: (context, t, _) => Stack(children: builder(t)),
          ),
        ),
      ],
    );
  }
}

/// A top-right control: an icon whose name fades in underneath when focused.
class ControlButton extends StatelessWidget {
  const ControlButton({super.key, required this.icon, required this.label, required this.focused});

  final String icon;
  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: focused ? 1 : 0,
            duration: fadeDuration,
            child: DecoratedBox(decoration: plate32, child: const SizedBox(width: 72, height: 64)),
          ),
          SvgPicture.asset(
            'assets/icons/$icon.svg',
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(ink.withValues(alpha: focused ? 1 : .84), BlendMode.srcIn),
          ),
          Positioned(
            top: 76,
            child: AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: fadeDuration,
              child: Text(label, softWrap: false, style: type(28, spacing: -.2, shadows: softShadow)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row in a panel list: icon and label, with the frosted plate when focused.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.icon, required this.label, required this.focused});

  final IconData icon;
  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final color = ink.withValues(alpha: focused ? 1 : .84);
    return SizedBox(
      width: 760,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: fadeDuration,
              child: const DecoratedBox(decoration: plate32),
            ),
          ),
          Positioned.fill(
            left: 32,
            right: 32,
            child: Row(
              children: [
                Icon(icon, size: 36, color: color),
                const SizedBox(width: 24),
                Text(label, style: type(36, spacing: -.8, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A rounded text button, solid when focused.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.focused});

  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: fadeDuration,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: focused ? solid : Colors.white.withValues(alpha: .12),
      ),
      child: Text(label, style: type(30, spacing: -.3, color: focused ? solidInk : ink)),
    );
  }
}
