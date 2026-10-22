import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'style.dart';

/// The strip above the dock: full dock width while Spotify plays, half width and centred otherwise.
const nowPlayingTop = 596.0;
const nowPlayingHeight = 112.0;
const _expandedLeft = 208.0;
const _expandedWidth = 1504.0;
const _collapsedWidth = _expandedWidth / 2;
const _collapsedLeft = _expandedLeft + (_expandedWidth - _collapsedWidth) / 2;
const _resizeDuration = Duration(milliseconds: 420);
// The strip resizes once a change has held this long. Spotify is busy for about a second as
// playback starts (resizing during that measured 20–60 ms frames on the TV, against ~14 ms after),
// and skipping a track can briefly report a pause.
const _settleDelay = Duration(milliseconds: 1500);

enum NowPlayingItem { info, previous, playPause, next }

/// Spotify's current (or last) track, from the media session MainActivity follows.
class NowPlayingStore extends ChangeNotifier {
  NowPlayingStore() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'update') _apply(call.arguments as Map<Object?, Object?>);
    });
    _channel.invokeMapMethod<Object?, Object?>('current').then((m) {
      if (m != null) _apply(m);
    });
  }

  static const _channel = MethodChannel('tv_home/media');

  bool session = false;
  bool playing = false;
  bool paused = false;
  String? title;
  String? artist;
  int durationMs = 0;
  Uint8List? art;

  /// Whether the strip is at full width; follows [playing] once it has settled.
  bool expanded = false;

  int _positionMs = 0;
  final _sincePosition = Stopwatch();
  Timer? _resize;

  int get positionMs {
    final ms = _positionMs + (playing ? _sincePosition.elapsedMilliseconds : 0);
    return durationMs > 0 ? ms.clamp(0, durationMs) : ms;
  }

  List<NowPlayingItem> get items => expanded
      ? NowPlayingItem.values
      : const [NowPlayingItem.info, NowPlayingItem.playPause];

  void _apply(Map<Object?, Object?> m) {
    session = m['session'] as bool;
    playing = m['state'] == 'playing';
    paused = m['state'] == 'paused';
    title = m['title'] as String?;
    artist = m['artist'] as String?;
    durationMs = (m['durationMs'] as num?)?.toInt() ?? 0;
    final newArt = m['art'] as Uint8List?;
    if (!listEquals(newArt, art)) art = newArt;
    _positionMs = (m['positionMs'] as num?)?.toInt() ?? 0;
    _sincePosition
      ..reset()
      ..start();
    if (playing == expanded) {
      _resize?.cancel();
    } else if (!(_resize?.isActive ?? false)) {
      _resize = Timer(_settleDelay, () {
        expanded = playing;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Returns false when there's no session to control, so the caller can open Spotify instead.
  Future<bool> _send(String method) async => await _channel.invokeMethod<bool>(method) ?? false;

  Future<bool> playPause() => _send(playing ? 'pause' : 'play');
  Future<bool> next() => _send('next');
  Future<bool> previous() => _send('previous');
}

/// The now-playing strip. Its glass is the same pre-blurred wallpaper as the dock's, so resizing
/// only moves a clip over a still image. Each state's content is laid out once at its own width and
/// stays put while the edges reveal or hide it, crossfading with the other.
class NowPlayingStrip extends StatelessWidget {
  const NowPlayingStrip({
    super.key,
    required this.store,
    required this.focused,
    required this.blurredWallpaper,
    required this.tint,
  });

  final NowPlayingStore store;
  final NowPlayingItem? focused;
  final Widget blurredWallpaper;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: store.expanded ? 1 : 0),
      duration: _resizeDuration,
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final left = lerpDouble(_collapsedLeft, _expandedLeft, t)!;
        final width = lerpDouble(_collapsedWidth, _expandedWidth, t)!;
        return Stack(
          children: [
            Positioned(
              left: left - _expandedLeft,
              top: 0,
              width: width,
              height: nowPlayingHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: -left, top: -nowPlayingTop, width: 1920, height: 1080, child: blurredWallpaper),
                    Positioned.fill(child: ColoredBox(color: tint)),
                    if (t < 1)
                      Positioned(
                        left: _collapsedLeft - left,
                        top: 0,
                        width: _collapsedWidth,
                        height: nowPlayingHeight,
                        child: Opacity(opacity: 1 - const Interval(0, .6).transform(t), child: _collapsed()),
                      ),
                    if (t > 0)
                      Positioned(
                        left: _expandedLeft - left,
                        top: 0,
                        width: _expandedWidth,
                        height: nowPlayingHeight,
                        child: Opacity(opacity: const Interval(.4, 1).transform(t), child: _expanded()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isFocused(NowPlayingItem item) => focused == item;

  Widget _expanded() {
    return Row(
      children: [
        _Info(
          focused: _isFocused(NowPlayingItem.info),
          art: store.art,
          maxWidth: 672,
          maxTextWidth: 520,
          children: [
            Text(store.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: type(28, weight: 600, spacing: -.6)),
            const SizedBox(height: 1),
            Text(store.artist ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: type(23, color: _muted)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(child: _Progress(store: store)),
        const SizedBox(width: 24),
        _Button(icon: Icons.skip_previous_rounded, focused: _isFocused(NowPlayingItem.previous)),
        const SizedBox(width: 6),
        _Button(
          icon: store.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          focused: _isFocused(NowPlayingItem.playPause),
          primary: true,
        ),
        const SizedBox(width: 6),
        _Button(icon: Icons.skip_next_rounded, focused: _isFocused(NowPlayingItem.next)),
        const SizedBox(width: 28),
      ],
    );
  }

  Widget _collapsed() {
    final label = store.title == null
        ? 'Spotify'
        : store.playing
            ? 'Playing'
            : store.paused
                ? 'Paused'
                : 'Last played';
    return Row(
      children: [
        Expanded(
          child: _Info(
            focused: _isFocused(NowPlayingItem.info),
            art: store.art,
            dimArt: true,
            maxTextWidth: 520,
            children: [
              Text(label.toUpperCase(), style: type(20, weight: 600, spacing: .4, color: _muted)),
              const SizedBox(height: 1),
              Text(store.title ?? 'Nothing played yet',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: type(28, weight: 600, spacing: -.6)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Shows the new state straight away, before the strip expands.
        _Button(
          icon: store.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          focused: _isFocused(NowPlayingItem.playPause),
          primary: true,
        ),
        const SizedBox(width: 28),
      ],
    );
  }
}

final _muted = ink.withValues(alpha: .7);

/// Art and two lines of text. Selecting it opens Spotify; its plate sits 8 px inside the strip.
class _Info extends StatelessWidget {
  const _Info({
    required this.focused,
    required this.art,
    required this.maxTextWidth,
    required this.children,
    this.dimArt = false,
    this.maxWidth = double.infinity,
  });

  final bool focused;
  final Uint8List? art;
  final bool dimArt;
  final double maxWidth;
  final double maxTextWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: focused ? 1 : 0,
              duration: fadeDuration,
              child: const DecoratedBox(decoration: plate32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: dimArt ? .55 : 1, child: _Art(art: art)),
                const SizedBox(width: 24),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxTextWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Art extends StatelessWidget {
  const _Art({required this.art});

  final Uint8List? art;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 72,
        height: 72,
        child: art == null
            ? ColoredBox(
                color: Colors.white.withValues(alpha: .12),
                child: Icon(Icons.music_note_rounded, size: 32, color: ink.withValues(alpha: .6)),
              )
            : Image.memory(art!, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// A round control: plain icon, the frosted plate if it's the main one, solid when focused.
class _Button extends StatelessWidget {
  const _Button({required this.icon, required this.focused, this.primary = false});

  final IconData icon;
  final bool focused;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: fadeDuration,
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: focused ? solid : Colors.white.withValues(alpha: primary ? .2 : 0),
      ),
      child: Icon(icon, size: 32, color: focused ? solidInk : ink),
    );
  }
}

/// Elapsed time, bar and length. Ticks on its own while playing, so the rest of the screen
/// doesn't rebuild every second.
class _Progress extends StatefulWidget {
  const _Progress({required this.store});

  final NowPlayingStore store;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (widget.store.playing) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static String _time(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final fraction = store.durationMs > 0 ? store.positionMs / store.durationMs : 0.0;
    final style = type(22, color: _muted).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Row(
      children: [
        Text(_time(store.positionMs), style: style),
        const SizedBox(width: 20),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: .18))),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: const ColoredBox(color: ink, child: SizedBox.expand()),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(store.durationMs > 0 ? _time(store.durationMs) : '', style: style),
      ],
    );
  }
}
