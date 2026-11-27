import 'package:flutter/material.dart';
export 'package:flex/responsive_content.dart';
export 'package:flex/responsive_settings_list.dart';

const double desktopBreakpoint = 900;
const double desktopMaxWidth = 1040;
const double wideMaxWidth = 1240;
const double dataMaxWidth = 1440;

/// Whether the current window should use Flex's desktop layout.
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

/// Shows a native-feeling popup menu at a desktop secondary-click position.
Future<T?> showDesktopContextMenu<T>(
  BuildContext context,
  Offset globalPosition,
  List<PopupMenuEntry<T>> items,
) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      localPosition & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
}
