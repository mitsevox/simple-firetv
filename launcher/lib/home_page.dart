import 'dart:async';
import 'dart:math';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apps.dart';
import 'brands.dart';
import 'style.dart';
import 'tiles.dart';
import 'wallpaper.dart';
import 'weather.dart';

/// Where remote focus is. Navigation is handled here directly rather than through Flutter's
/// focus traversal, so it behaves exactly as specified: no wrapping, and Back steps out one level.
enum Zone { dock, controls, allApps, settings, exitPrompt }

const _dockLeft = 208.0;
// Bottom edge stays where CleanFrame's taller labelled dock ended (908).
const _dockTop = 908.0 - dockTileHeight;
const _dockWidth = 1504.0;
// The first and last tiles sit this far in from the dock's edges; scrolled tiles run to the edge.
const _shelfInset = 16.0;
const _shelfWidth = _dockWidth - 2 * _shelfInset;
// Where the dock can scroll further, tiles fade to nothing over this distance from its edge: fully
// clear for the outer _dockFadeClear px, then easing in, so nothing is visible where it's cut off.
const _dockFade = 160.0;
const _dockFadeClear = 24.0;
const _gridTop = 200.0;
const _gridColumns = 5;
const _gridVisibleRows = 3;

/// Fire OS settings screens any app may open, as (icon, label, activity in com.amazon.tv.settings.v2).
/// The rest (Display & Sounds, Preferences, Accessibility, My Account) are restricted to Amazon's
/// own apps, so the last row opens Amazon's Settings with the Home redirect paused instead.
const _settingsRows = <(IconData, String, String?)>[
  (Icons.wifi_rounded, 'Network', 'tv.network.NetworkActivity'),
  (Icons.bluetooth_rounded, 'Remotes & Bluetooth', 'tv.controllers_bluetooth_devices.ControllersAndBluetoothActivity'),
  (Icons.apps_rounded, 'Applications', 'tv.applications.ApplicationsActivity'),
  (Icons.tv_rounded, 'Device & software', 'tv.device.DeviceActivity'),
  (Icons.tune_rounded, 'More settings', null),
];

/// Build with --dart-define=MARK_CHECK=true to draw every app that has a mark as a real dock tile
/// on black, for tool/check_marks.py to measure from a screenshot.
const _markCheck = bool.fromEnvironment('MARK_CHECK');
const markCheckOrigin = Offset(64, 64);
const markCheckColumns = 8;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _apps = AppStore();
  final _wallpapers = WallpaperStore();
  final _weather = WeatherStore();
  final _focus = FocusNode();

  Zone _zone = Zone.dock;
  int _dockIndex = 0;
  int _controlIndex = 0;
  int _gridIndex = 0;
  int _promptIndex = 0;
  int _settingsIndex = 0;
  double _dockOffset = 0;
  int _gridRowOffset = 0;

  // A held OK fires once: as a hold action if it repeats, otherwise as a press on release.
  bool _selectDown = false;
  bool _selectHeld = false;

  DateTime _now = DateTime.now();
  Timer? _clock;

  late final _controls = <(String, String, VoidCallback)>[
    ('art', 'Wallpaper', () => _wallpapers.next()),
    ('apps', 'All apps', _openAllApps),
    ('settings', 'Settings', _openSettings),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final store in [_apps, _wallpapers, _weather]) {
      store.addListener(_changed);
    }
    _apps.load();
    _wallpapers.load();
    _weather.start();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      if (now.minute != _now.minute) setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _weather.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _apps.load();
      setState(() => _now = DateTime.now());
      _focus.requestFocus();
    }
  }

  void _changed() => setState(() {
        _dockIndex = min(_dockIndex, max(0, _apps.dock.length - 1));
        _gridIndex = min(_gridIndex, max(0, _apps.all.length - 1));
      });

  // ---- Remote input ----

  static bool _isSelect(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  static bool _isBack(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.browserBack;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (_isSelect(key)) {
      if (event is KeyDownEvent) {
        _selectDown = true;
        _selectHeld = false;
      } else if (event is KeyRepeatEvent && _selectDown && !_selectHeld) {
        _selectHeld = true;
        _hold();
      } else if (event is KeyUpEvent) {
        if (_selectDown && !_selectHeld) _activate();
        _selectDown = false;
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      if (event is KeyDownEvent) _back();
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final (dx, dy) = switch (key) {
      LogicalKeyboardKey.arrowLeft => (-1, 0),
      LogicalKeyboardKey.arrowRight => (1, 0),
      LogicalKeyboardKey.arrowUp => (0, -1),
      LogicalKeyboardKey.arrowDown => (0, 1),
      _ => (0, 0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    setState(() => _move(dx, dy));
    return KeyEventResult.handled;
  }

  void _move(int dx, int dy) {
    switch (_zone) {
      case Zone.dock:
        if (dy < 0) {
          _zone = Zone.controls;
        } else if (dx != 0 && _apps.dock.isNotEmpty) {
          _dockIndex = (_dockIndex + dx).clamp(0, _apps.dock.length - 1);
          _dockOffset = _scrollToShow(_dockIndex * dockTileWidth, dockTileWidth, _dockOffset, _shelfWidth,
              _apps.dock.length * dockTileWidth, margin: _dockFade - _shelfInset);
        }
      case Zone.controls:
        if (dy > 0) {
          _zone = Zone.dock;
        } else if (dx != 0) {
          _controlIndex = (_controlIndex + dx).clamp(0, _controls.length - 1);
        }
      case Zone.allApps:
        final count = _apps.all.length;
        if (count == 0) return;
        if (dx != 0) {
          _gridIndex = (_gridIndex + dx).clamp(0, count - 1);
        } else if (dy > 0 && _gridIndex ~/ _gridColumns < (count - 1) ~/ _gridColumns) {
          _gridIndex = min(_gridIndex + _gridColumns, count - 1);
        } else if (dy < 0 && _gridIndex >= _gridColumns) {
          _gridIndex -= _gridColumns;
        }
        final row = _gridIndex ~/ _gridColumns;
        if (row < _gridRowOffset) _gridRowOffset = row;
        if (row >= _gridRowOffset + _gridVisibleRows) _gridRowOffset = row - _gridVisibleRows + 1;
      case Zone.settings:
        if (dy != 0) _settingsIndex = (_settingsIndex + dy).clamp(0, _settingsRows.length - 1);
      case Zone.exitPrompt:
        if (dx != 0) _promptIndex = (_promptIndex + dx).clamp(0, 1);
    }
  }

  /// Scrolls just enough to bring an item fully into view, at least [margin] in from either edge
  /// (so it stays clear of the fades), never past either end.
  static double _scrollToShow(double start, double size, double offset, double viewport, double total,
      {double margin = 0}) {
    if (start - margin < offset) offset = start - margin;
    if (start + size + margin > offset + viewport) offset = start + size + margin - viewport;
    return offset.clamp(0, max(0, total - viewport));
  }

  void _activate() {
    switch (_zone) {
      case Zone.dock:
        if (_apps.dock.isNotEmpty) AppStore.launch(_apps.dock[_dockIndex].package);
      case Zone.controls:
        _controls[_controlIndex].$3();
      case Zone.allApps:
        if (_apps.all.isNotEmpty) AppStore.launch(_apps.all[_gridIndex].package);
      case Zone.settings:
        final page = _settingsRows[_settingsIndex].$3;
        page == null ? AppStore.openFireSettings() : AppStore.openSettingsPage(page);
      case Zone.exitPrompt:
        if (_promptIndex == 1) AppStore.openFireHome();
        setState(() => _zone = Zone.dock);
    }
  }

  void _hold() {
    if (_zone == Zone.allApps && _apps.all.isNotEmpty) _apps.togglePin(_apps.all[_gridIndex].package);
  }

  void _back() => setState(() {
        switch (_zone) {
          case Zone.dock:
            _zone = Zone.exitPrompt;
            _promptIndex = 0;
          case Zone.controls || Zone.exitPrompt:
            _zone = Zone.dock;
          case Zone.allApps || Zone.settings:
            _zone = Zone.controls;
        }
      });

  void _openAllApps() => setState(() {
        _zone = Zone.allApps;
        _gridIndex = 0;
        _gridRowOffset = 0;
      });

  void _openSettings() => setState(() {
        _zone = Zone.settings;
        _settingsIndex = 0;
      });

  // ---- Layout ----

  @override
  Widget build(BuildContext context) {
    if (_markCheck) return _markCheckSheet();
    final wallpaper = _wallpapers.frame?.info;
    final panelOpen = _zone == Zone.allApps || _zone == Zone.settings || _zone == Zone.exitPrompt;
    return PopScope(
      canPop: false,
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(child: _wallpaperLayer((frame) => frame.photo)),
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 320,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x40000000), Color(0x00000000)],
                  ),
                ),
              ),
            ),
            Positioned(left: 112, top: 72, child: _clockAndWeather()),
            Positioned(right: 112, top: 72, child: _controlRow()),
            Positioned(left: _dockLeft, top: _dockTop, width: _dockWidth, height: dockTileHeight, child: _dock()),
            if (wallpaper != null && !panelOpen)
              Positioned(
                right: 112,
                bottom: 40,
                child: Text(
                  'Photo: ${wallpaper.credit} / Unsplash',
                  style: type(22, color: ink.withValues(alpha: .55), shadows: softShadow),
                ),
              ),
            if (_zone == Zone.allApps) Positioned.fill(child: _allApps()),
            if (_zone == Zone.settings) Positioned.fill(child: _settingsPanel()),
            if (_zone == Zone.exitPrompt) Positioned.fill(child: _exitPrompt()),
          ],
        ),
      ),
    );
  }

  Widget _clockAndWeather() {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final time = '$hour:${_now.minute.toString().padLeft(2, '0')}';
    final weather = _weather.current;
    final muted = ink.withValues(alpha: .88);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 64,
          child: Text(
            time,
            style: type(56, spacing: -1.5, shadows: softShadow)
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        if (weather != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(weather.icon, size: 30, color: muted, shadows: softShadow),
              const SizedBox(width: 12),
              Text('${weather.temperature}°  ${weather.summary}',
                  style: type(30, spacing: -.2, color: muted, shadows: softShadow)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _controlRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (icon, label, _)) in _controls.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          ControlButton(icon: icon, label: label, focused: _zone == Zone.controls && _controlIndex == i),
        ],
      ],
    );
  }

  /// A full-screen layer of the current wallpaper frame. The photo and the blurred glass both use
  /// this, so they start the same crossfade on the same frame and stay in step.
  /// The outgoing image stays fully opaque underneath until the new one has faded in over it.
  Widget _wallpaperLayer(ui.Image Function(WallpaperFrame) image) {
    final frame = _wallpapers.frame;
    return AnimatedSwitcher(
      duration: wallpaperFadeDuration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: const Threshold(0),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: frame == null
          ? const SizedBox.expand()
          : RawImage(
              key: ValueKey(frame.info.id),
              image: image(frame),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
    );
  }

  Widget _blurredWallpaper() => _wallpaperLayer((frame) => frame.blurred);

  Widget _dock() {
    final dock = _apps.dock;
    final total = dock.length * dockTileWidth;
    final fadeLeft = _dockOffset > 0;
    final fadeRight = _dockOffset < total - _shelfWidth;
    final (fadeStops, fadeAlphas) = _fadeCurve();
    final light = _wallpapers.frame?.info.light ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(48),
      child: Stack(
        children: [
          // Lines the blur up with the photo behind it, so the glass looks see-through.
          Positioned(left: -_dockLeft, top: -_dockTop, width: 1920, height: 1080, child: _blurredWallpaper()),
          Positioned.fill(
            child: ColoredBox(color: const Color(0xFF080E12).withValues(alpha: light ? .27 : .16)),
          ),
          // Spans the whole dock so anything scrolled out is cut by the dock's own edge, where the
          // fade has already taken it to nothing.
          Positioned.fill(
            child: dock.isEmpty
                ? Center(child: Text('Add apps from All apps', style: type(36, spacing: -.6)))
                : ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => LinearGradient(
                      colors: [
                        for (final a in fadeAlphas) Colors.white.withValues(alpha: fadeLeft ? a : 1),
                        for (final a in fadeAlphas.reversed) Colors.white.withValues(alpha: fadeRight ? a : 1),
                      ],
                      stops: [...fadeStops, for (final t in fadeStops.reversed) 1 - t],
                    ).createShader(rect),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: moveDuration,
                            curve: ease,
                            left: _shelfInset - _dockOffset,
                            top: 0,
                            width: total,
                            height: dockTileHeight,
                            child: Row(
                              children: [
                                for (final (i, app) in dock.indexed)
                                  DockTile(
                                    key: ValueKey(app.package),
                                    app: app,
                                    focused: _zone == Zone.dock && _dockIndex == i,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Gradient stops (as fractions of the dock's width) and alphas for one edge of the dock fade:
  /// clear for [_dockFadeClear], then a smoothstep up to full opacity at [_dockFade].
  static (List<double>, List<double>) _fadeCurve() {
    const steps = 8;
    final stops = <double>[0];
    final alphas = <double>[0];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      stops.add((_dockFadeClear + t * (_dockFade - _dockFadeClear)) / _dockWidth);
      alphas.add(t * t * (3 - 2 * t));
    }
    return (stops, alphas);
  }

  Widget _panelBackdrop() => Stack(
        children: [
          Positioned.fill(child: _blurredWallpaper()),
          const Positioned.fill(child: ColoredBox(color: Color(0x80080E12))),
        ],
      );

  Widget _allApps() {
    return Stack(
      children: [
        Positioned.fill(child: _panelBackdrop()),
        Positioned(left: _dockLeft, top: 88, child: Text('All apps', style: type(48, weight: 600, spacing: -1.5))),
        Positioned(
          right: _dockLeft,
          top: 102,
          child: Text('Hold OK to add or remove from Home', style: type(28, color: ink.withValues(alpha: .7))),
        ),
        Positioned(
          left: _dockLeft,
          top: _gridTop,
          width: 1504,
          bottom: 0,
          child: ClipRect(
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: moveDuration,
                  curve: ease,
                  left: 0,
                  right: 0,
                  top: -_gridRowOffset * gridTileHeight,
                  child: Wrap(
                    spacing: 16,
                    children: [
                      for (final (i, app) in _apps.all.indexed)
                        AllAppsTile(
                          key: ValueKey(app.package),
                          app: app,
                          focused: _gridIndex == i,
                          onHome: _apps.isPinned(app.package),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsPanel() {
    return Stack(
      children: [
        Positioned.fill(child: _panelBackdrop()),
        Positioned(left: _dockLeft, top: 88, child: Text('Settings', style: type(48, weight: 600, spacing: -1.5))),
        Positioned(
          left: _dockLeft,
          top: _gridTop,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (icon, label, _)) in _settingsRows.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                ListRow(icon: icon, label: label, focused: _settingsIndex == i),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _exitPrompt() {
    return Stack(
      children: [
        Positioned.fill(child: _panelBackdrop()),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Open Fire TV home?', style: type(48, weight: 600, spacing: -1.5)),
              const SizedBox(height: 16),
              Text(
                'The Home button comes back here after 5 minutes.',
                style: type(30, color: ink.withValues(alpha: .75)),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Pill(label: 'Stay', focused: _promptIndex == 0),
                  const SizedBox(width: 16),
                  Pill(label: 'Open Fire TV home', focused: _promptIndex == 1),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _markCheckSheet() {
    final apps = [for (final app in _apps.all) if (brands.containsKey(app.package)) app];
    debugPrint('MARKS: ${apps.map((app) => brands[app.package]!.icon).join(',')}');
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Stack(
        children: [
          for (final (i, app) in apps.indexed)
            Positioned(
              left: markCheckOrigin.dx + (i % markCheckColumns) * dockTileWidth,
              top: markCheckOrigin.dy + (i ~/ markCheckColumns) * dockTileHeight,
              child: DockTile(app: app, focused: false),
            ),
        ],
      ),
    );
  }
}
