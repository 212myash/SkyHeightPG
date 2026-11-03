import 'package:flutter/material.dart';

/// Wraps content so tapping anywhere outside an active text input dismisses the keyboard
class KeyboardDismissible extends StatelessWidget {
  final Widget child;

  const KeyboardDismissible({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      child: child,
    );
  }
}

/// A scroll view that dynamically respects software keyboards, adjusts bottom insets,
/// and enables smooth scrolling for form inputs.
class KeyboardAwareScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final ScrollPhysics physics;

  const KeyboardAwareScrollView({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.physics = const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: controller,
          physics: physics,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Helper utility for programmatically bringing an input field into view upon validation failure
class FormScrollHelper {
  FormScrollHelper._();

  static void ensureVisible(GlobalKey fieldKey) {
    final ctx = fieldKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1, // Near top of viewport
      );
    }
  }
}
