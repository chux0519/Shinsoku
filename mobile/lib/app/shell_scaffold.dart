import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

/// App chrome around the four pages (Record, Drafts, Desktop, Settings),
/// chosen from the constraints, never from the device model.
///
/// * **Compact** (either side < [regularExtent]: iPhone, iPhone Duo folded,
///   the inner display in Split View): one page at a time, bottom tab bar.
/// * **Regular** (both sides ≥ [regularExtent]: iPhone Duo inner display):
///   two panes split at the fold (DESIGN §6). Record stays in one pane; the
///   other pane shows Drafts, Desktop or Settings, picked with a switcher at
///   its top edge. Side by side when the fold is vertical (book, or landscape
///   when flat); stacked when it is horizontal (tabletop, or portrait when
///   flat), with Record in the lower half (content up, controls down).
///   Stacked with the software keyboard up for a field in Record: the
///   switchable pane steps aside and Record gets the whole window until the
///   keyboard goes down (live-01 decision 2026-11-19, invariant D3).
///
/// Each page keeps its element (and so its state) across compact ↔ regular
/// switches: pages sit under [GlobalKey]s that move between the layouts.
/// Recording state itself lives above this widget, in `MobileShell`.
class ShellScaffold extends StatefulWidget {
  const ShellScaffold({
    required this.tabIndex,
    required this.onTabSelected,
    required this.pages,
    this.secondaryIndex = 1,
    this.holdRecord = false,
    super.key,
  }) : assert(pages.length == 4),
       assert(secondaryIndex >= 1 && secondaryIndex < 4);

  /// The page shown on compact widths (0 = Record).
  final int tabIndex;

  /// The page in the second pane on regular widths (1–3).
  final int secondaryIndex;

  /// Called with a page index from the tab bar or the pane switcher.
  final ValueChanged<int> onTabSelected;

  /// While true (a capture is running), a regular → compact switch shows
  /// Record, so Stop is in reach after folding (invariant D2). The shell
  /// shows it at once and reports `onTabSelected(0)` after the frame.
  final bool holdRecord;

  /// Record, Drafts, Desktop, Settings — in [tabs] order.
  final List<Widget> pages;

  /// Both window sides at least this wide → two panes (Material's
  /// compact/medium boundary; on iPhone Duo it matches the regular × regular
  /// size class of the inner display, 951 × 669).
  static const double regularExtent = 600;

  /// A pane narrower than this falls back to the compact layout (an
  /// off-centre fold that would leave a sliver).
  static const double minPaneExtent = 280;

  /// Minimum space kept free around the fold, centred on it (iPhone Duo kit:
  /// 24 pt pane gap inner display; the real region is used when wider).
  static const double foldGap = 24;

  static const tabs = [
    SkTabItem(icon: Icons.mic_none, selectedIcon: Icons.mic, label: 'Record'),
    SkTabItem(
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: 'Drafts',
    ),
    SkTabItem(
      icon: Icons.wifi_tethering,
      selectedIcon: Icons.podcasts,
      label: 'Desktop',
    ),
    SkTabItem(
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      label: 'Settings',
    ),
  ];

  /// The two-pane split for a window of [size] with [features] (window
  /// coordinates), or null for the compact layout.
  static PaneSplit? splitFor(Size size, List<DisplayFeature> features) {
    if (size.width < regularExtent || size.height < regularExtent) return null;
    final window = Offset.zero & size;
    Rect? fold;
    for (final feature in features) {
      if (feature.type == DisplayFeatureType.cutout) continue;
      final b = feature.bounds;
      final vertical = b.height > b.width;
      // Only a fold that crosses the whole window divides it.
      final crosses = vertical
          ? b.top <= 1 && b.bottom >= size.height - 1
          : b.left <= 1 && b.right >= size.width - 1;
      final inside = vertical
          ? b.left >= 0 && b.right <= size.width
          : b.top >= 0 && b.bottom <= size.height;
      if (crosses && inside) {
        fold = b.intersect(window);
        break;
      }
    }
    final sideBySide = fold != null
        ? fold.height > fold.width
        : size.width >= size.height;
    final extent = sideBySide ? size.width : size.height;
    final (double start, double end) = fold == null
        ? (extent / 2, extent / 2)
        : sideBySide
        ? (fold.left, fold.right)
        : (fold.top, fold.bottom);
    final pad = math.max(0.0, (foldGap - (end - start)) / 2);
    final split = PaneSplit(
      sideBySide: sideBySide,
      firstEnd: start - pad,
      secondStart: end + pad,
      extent: extent,
      fromFold: fold != null,
    );
    if (split.firstEnd < minPaneExtent ||
        extent - split.secondStart < minPaneExtent) {
      return null;
    }
    return split;
  }

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

/// Where the two panes meet. Offsets are along the split axis, in window
/// coordinates: the first pane is `[0, firstEnd]`, the second
/// `[secondStart, extent]`; nothing is drawn in between but a hairline.
@immutable
class PaneSplit {
  const PaneSplit({
    required this.sideBySide,
    required this.firstEnd,
    required this.secondStart,
    required this.extent,
    required this.fromFold,
  });

  /// Left | right (vertical fold) rather than top / bottom.
  final bool sideBySide;
  final double firstEnd;
  final double secondStart;
  final double extent;

  /// Placed at a reported fold rather than at the centre.
  final bool fromFold;

  @override
  bool operator ==(Object other) =>
      other is PaneSplit &&
      other.sideBySide == sideBySide &&
      other.firstEnd == firstEnd &&
      other.secondStart == secondStart &&
      other.extent == extent &&
      other.fromFold == fromFold;

  @override
  int get hashCode =>
      Object.hash(sideBySide, firstEnd, secondStart, extent, fromFold);

  @override
  String toString() =>
      'PaneSplit(${sideBySide ? 'side by side' : 'stacked'}, '
      '$firstEnd–$secondStart of $extent${fromFold ? ', fold' : ''})';
}

class _ShellScaffoldState extends State<ShellScaffold> {
  // One key per page: the page subtree moves between layouts without being
  // rebuilt from scratch (scroll positions, Nearby connection, form fields).
  final _pageKeys = List.generate(4, (i) => GlobalKey(debugLabel: 'page $i'));

  bool _wasRegular = false;

  /// Has focus somewhere inside the Record page (its transcript field).
  final _recordFocus = FocusNode(
    debugLabel: 'record page',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    _recordFocus.addListener(_onRecordFocus);
  }

  @override
  void dispose() {
    _recordFocus.dispose();
    super.dispose();
  }

  void _onRecordFocus() => setState(() {});

  /// Record is shown in compact although [ShellScaffold.tabIndex] is not 0
  /// yet (D2 fold, until the parent catches up or the user picks a tab).
  bool _showRecord = false;

  Widget _page(int i, {required bool visible}) {
    // Hidden pages keep their state but not their animations.
    Widget page = TickerMode(enabled: visible, child: widget.pages[i]);
    if (i == 0) {
      page = Focus(
        focusNode: _recordFocus,
        includeSemantics: false,
        child: page,
      );
    }
    return KeyedSubtree(key: _pageKeys[i], child: page);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = ShellScaffold.splitFor(
          constraints.biggest,
          MediaQuery.displayFeaturesOf(context),
        );
        final regular = split != null;
        if (_wasRegular &&
            !regular &&
            widget.holdRecord &&
            widget.tabIndex != 0) {
          _showRecord = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _showRecord) widget.onTabSelected(0);
          });
        }
        if (widget.tabIndex == 0) _showRecord = false;
        _wasRegular = regular;
        return split == null
            ? _compact(_showRecord ? 0 : widget.tabIndex)
            : _regular(context, split);
      },
    );
  }

  Widget _compact(int index) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: [for (var i = 0; i < 4; i++) _page(i, visible: i == index)],
        ),
      ),
      bottomNavigationBar: SkTabBar(
        items: ShellScaffold.tabs,
        selectedIndex: index,
        onSelected: (i) {
          _showRecord = false;
          widget.onTabSelected(i);
        },
      ),
    );
  }

  Widget _regular(BuildContext context, PaneSplit split) {
    final c = SkColors.of(context);
    // D3: stacked, keyboard up for Record → Record takes the window.
    final recordOnly =
        !split.sideBySide &&
        _recordFocus.hasFocus &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final record = _page(0, visible: true);
    final secondary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaneSwitcher(
          selected: widget.secondaryIndex,
          onSelected: widget.onTabSelected,
        ),
        Expanded(
          child: SkTitledByChrome(
            child: IndexedStack(
              index: widget.secondaryIndex - 1,
              children: [
                for (var i = 1; i < 4; i++)
                  _page(i, visible: i == widget.secondaryIndex),
              ],
            ),
          ),
        ),
      ],
    );
    // Side by side: Record left, the switchable pane right (tools on the
    // trailing side, where iPhone Duo also puts its vertical bar). Stacked:
    // the switchable pane up, Record and its button in the lower half.
    final (Widget first, Widget second) = split.sideBySide
        ? (record, secondary)
        : (secondary, record);
    final gap = recordOnly ? 0.0 : split.secondStart - split.firstEnd;
    final seam = split.sideBySide
        ? Center(
            child: Container(width: SkShape.hairline, color: c.hairline),
          )
        : Center(
            child: Container(height: SkShape.hairline, color: c.hairline),
          );
    return Scaffold(
      body: Flex(
        direction: split.sideBySide ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: split.sideBySide ? split.firstEnd : null,
            height: split.sideBySide
                ? null
                : recordOnly
                ? 0
                : split.firstEnd,
            // Stepped aside (D3): still built at its size, so its pages keep
            // their state, but not painted, hit or read.
            child: Offstage(
              offstage: recordOnly,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: split.sideBySide ? null : split.firstEnd,
                maxHeight: split.sideBySide ? null : split.firstEnd,
                child: _Pane(
                  key: const ValueKey('pane-first'),
                  sideBySide: split.sideBySide,
                  first: true,
                  child: first,
                ),
              ),
            ),
          ),
          // The fold: nothing interactive or text-bearing here.
          SizedBox(
            width: split.sideBySide ? gap : null,
            height: split.sideBySide ? null : gap,
            child: ExcludeSemantics(child: seam),
          ),
          Expanded(
            child: _Pane(
              key: const ValueKey('pane-second'),
              sideBySide: split.sideBySide,
              first: false,
              whole: recordOnly,
              child: second,
            ),
          ),
        ],
      ),
    );
  }
}

/// One pane: it keeps the safe insets of the window edges it touches and
/// drops the others, so a trailing bar inset (iPhone Duo landscape) or a top
/// / bottom bar inset (portrait) lands only on the pane that meets it.
class _Pane extends StatelessWidget {
  const _Pane({
    required this.sideBySide,
    required this.first,
    required this.child,
    this.whole = false,
    super.key,
  });

  final bool sideBySide;
  final bool first;

  /// The only pane on screen (D3): keeps every safe inset.
  final bool whole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeLeft: !whole && sideBySide && !first,
      removeRight: !whole && sideBySide && first,
      removeTop: !whole && !sideBySide && !first,
      removeBottom: !whole && !sideBySide && first,
      child: SafeArea(child: child),
    );
  }
}

/// The second pane's own top switcher (Drafts / Desktop / Settings).
class _PaneSwitcher extends StatelessWidget {
  const _PaneSwitcher({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = skPageInsets(context, constraints.maxWidth);
        return Padding(
          padding: insets.copyWith(top: SkSpace.s, bottom: SkSpace.s),
          child: SkSegmented<int>(
            key: const ValueKey('pane-switcher'),
            semanticLabel: 'Pane',
            segments: [
              for (var i = 1; i < 4; i++)
                // Labels only: three icons + labels do not fit a ~380 pt pane.
                SkSegment(value: i, label: ShellScaffold.tabs[i].label),
            ],
            selected: selected,
            onChanged: onSelected,
          ),
        );
      },
    );
  }
}
