import 'package:flex/constants.dart';
import 'package:flex/database/database.dart';
import 'package:flex/plan/set_chip.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Strong/Hevy-style strip of the sets already logged in the active workout
/// for the selected exercise.
class SessionSets extends StatefulWidget {
  final int exerciseId;
  final List<ExerciseSetView> sets;
  final int workoutId;
  final bool compact;
  final List<ExerciseSetView>? previous;
  final ValueChanged<ExerciseSetView>? onPreviousSetTap;

  const SessionSets({
    super.key,
    required this.exerciseId,
    required this.sets,
    required this.workoutId,
    this.compact = false,
    this.previous,
    this.onPreviousSetTap,
  });

  @override
  State<SessionSets> createState() => _SessionSetsState();
}

class _SessionSetsState extends State<SessionSets> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _focusSetKey = GlobalKey();
  int _lastSetCount = 0;

  @override
  void didUpdateWidget(SessionSets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId ||
        oldWidget.workoutId != widget.workoutId) {
      _lastSetCount = 0;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNextSet(int setCount) {
    if (setCount <= _lastSetCount) return;
    _lastSetCount = setCount;
    final exerciseId = widget.exerciseId;
    final workoutId = widget.workoutId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_scrollController.hasClients ||
          exerciseId != widget.exerciseId ||
          workoutId != widget.workoutId ||
          setCount != _lastSetCount) {
        return;
      }
      final target = _focusSetKey.currentContext?.findRenderObject();
      if (target == null) return;
      final position = _scrollController.position;
      final offset = RenderAbstractViewport.of(
        target,
      ).getOffsetToReveal(target, 1).offset;
      final destination = offset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((destination - position.pixels).abs() < 0.5) return;
      _scrollController.animateTo(
        destination,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sets = widget.sets;
    if (sets.isNotEmpty) _scrollToNextSet(sets.length);

    if (sets.isEmpty) {
      final previous = widget.previous;
      if (previous == null || previous.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildPreviousChips(previous);
    }

    if (!widget.compact) return _buildChips(sets);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _buildChips(sets),
    );
  }

  void _scrollWithMouseWheel(BuildContext context, PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dx != 0 ||
        event.scrollDelta.dy == 0) {
      return;
    }
    final position = Scrollable.of(context).position;
    if (!position.physics.shouldAcceptUserOffset(position)) return;
    final delta = position.axisDirection == AxisDirection.left
        ? -event.scrollDelta.dy
        : event.scrollDelta.dy;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      position.pointerScroll(delta);
    });
  }

  // The scrolling region fills the space beside Save. When the keyboard is
  // visible, short strips must align their actual cards to its trailing edge;
  // otherwise a blank viewport can remain between the cards and the FAB.
  Widget _scrollingChips({
    required Key key,
    required List<Widget> children,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
  }) {
    final alignToSave =
        widget.compact && MediaQuery.viewInsetsOf(context).bottom > 0;
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        key: key,
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Builder(
          builder: (context) => Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (event) => _scrollWithMouseWheel(context, event),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: alignToSave && viewport.hasBoundedWidth
                    ? viewport.maxWidth
                    : 0,
              ),
              child: Row(
                mainAxisAlignment: alignToSave
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousChips(List<ExerciseSetView> previous) => _scrollingChips(
    key: const Key('previous-set-scroll'),
    children: _chips(const [], previous),
  );

  List<Widget> _chips(
    List<ExerciseSetView> current,
    List<ExerciseSetView> previous,
  ) {
    final best = _bestId(current);
    final total = current.length > previous.length
        ? current.length
        : previous.length;
    final focus = current.length >= previous.length
        ? current.length - 1
        : current.length;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return [
      for (var i = 0; i < total; i++)
        Padding(
          key: current.isNotEmpty && i == focus ? _focusSetKey : null,
          padding: EdgeInsets.only(
            right: widget.compact && keyboardOpen && i == total - 1 ? 4 : 8,
          ),
          child: SetChip(
            exerciseSet: i < current.length ? current[i] : previous[i],
            previous: i >= current.length,
            onPreviousTap: widget.onPreviousSetTap,
            number: i + 1,
            best: i < current.length && current[i].id == best,
            compact: widget.compact,
          ),
        ),
    ];
  }

  Widget _buildChips(List<ExerciseSetView> sets) => _scrollingChips(
    key: const Key('session-set-scroll'),
    controller: _scrollController,
    padding: widget.compact
        ? const EdgeInsets.symmetric(vertical: 6)
        : EdgeInsets.zero,
    children: _chips(sets, widget.previous ?? const []),
  );

  /// Id of the top set this session, using the measurement shown to the user.
  int? _bestId(List<ExerciseSetView> sets) {
    if (sets.length < 2) return null;
    final cardio = sets.first.cardio;
    final weightedCardio = cardio && isWeightUnit(sets.first.unit);
    final best = sets.reduce((a, b) {
      if (!cardio) return b.weight > a.weight ? b : a;
      if (!weightedCardio) return b.distance > a.distance ? b : a;
      if (b.weight != a.weight) return b.weight > a.weight ? b : a;
      return b.duration > a.duration ? b : a;
    });
    final metric = cardio && !weightedCardio ? best.distance : best.weight;
    if (metric <= 0) return null;
    return best.id;
  }
}
