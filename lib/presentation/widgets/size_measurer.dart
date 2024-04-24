import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class SizeMeasurerNotification extends Notification {
  final double height;

  SizeMeasurerNotification(this.height);
}

class SizeMeasurer extends StatefulWidget {
  final Widget child;
  final void Function(Size size)? onSizeChange;
  final bool useNotification;

  const SizeMeasurer({
    super.key,
    this.onSizeChange,
    required this.child,
    this.useNotification = false,
  });

  @override
  State createState() => _SizeMeasurerState();
}

class _SizeMeasurerState extends State<SizeMeasurer> {
  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback(_postFrameCallback);
    return Container(
      key: widgetKey,
      child: widget.child,
    );
  }

  final widgetKey = GlobalKey();
  Size? oldSize;

  void _postFrameCallback(_) {
    var context = widgetKey.currentContext;
    if (context == null) return;

    final newSize = context.size;
    if (oldSize == newSize) return;

    oldSize = newSize;
    if (widget.useNotification) {
      SizeMeasurerNotification(newSize!.height).dispatch(context);
    }
    widget.onSizeChange?.call(newSize!);
  }
}
