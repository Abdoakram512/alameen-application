import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ويدجت للتمرير السلس بلوحة المفاتيح (الأسهم و PageUp/PageDown) على الديسكتوب والويب.
class DesktopKeyboardScroller extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;

  const DesktopKeyboardScroller({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  State<DesktopKeyboardScroller> createState() =>
      _DesktopKeyboardScrollerState();
}

class _DesktopKeyboardScrollerState extends State<DesktopKeyboardScroller> {
  late final FocusNode _focusNode;
  ScrollController? _internalController;

  ScrollController get _effectiveController =>
      widget.controller ??
      _internalController ??
      PrimaryScrollController.maybeOf(context) ??
      (_internalController = ScrollController());

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'DesktopKeyboardScrollerFocus');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _internalController?.dispose();
    super.dispose();
  }

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    final widget = focus?.context?.widget;
    return widget is EditableText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // عدم مقاطعة المستخدم أثناء الكتابة في حقول النصوص
    if (_isEditingText()) {
      return KeyEventResult.ignored;
    }

    final controller = _effectiveController;
    if (!controller.hasClients) {
      return KeyEventResult.ignored;
    }

    final position = controller.position;
    final currentOffset = controller.offset;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;

    const arrowDelta = 90.0;
    const pageDelta = 380.0;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final target = (currentOffset + arrowDelta).clamp(min, max);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final target = (currentOffset - arrowDelta).clamp(min, max);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageDown ||
        event.logicalKey == LogicalKeyboardKey.space) {
      final target = (currentOffset + pageDelta).clamp(min, max);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
      final target = (currentOffset - pageDelta).clamp(min, max);
      controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      controller.animateTo(
        min,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      controller.animateTo(
        max,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.controller != null
          ? widget.child
          : PrimaryScrollController(
              controller: _effectiveController,
              child: widget.child,
            ),
    );
  }
}

