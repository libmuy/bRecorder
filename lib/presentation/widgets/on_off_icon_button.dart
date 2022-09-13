import 'package:brecorder/core/logging.dart';
import 'package:flutter/material.dart';

final log = Logger('OnOffIconButton');

class OnOffIconButton extends StatefulWidget {
  final IconData icon;
  final void Function(bool state)? onStateChanged;
  final ValueNotifier<bool>? stateNotifier;

  const OnOffIconButton({
    Key? key,
    required this.icon,
    this.onStateChanged,
    this.stateNotifier,
  }) : super(key: key);

  @override
  State<OnOffIconButton> createState() => _OnOffIconButtonState();
}

class _OnOffIconButtonState extends State<OnOffIconButton> {
  late final ValueNotifier<bool> stateNotifier =
      widget.stateNotifier ?? ValueNotifier(false);

  @override
  Widget build(context) {
    return IconButton(
        splashRadius: 20,
        onPressed: () {
          stateNotifier.value = !stateNotifier.value;
          widget.onStateChanged?.call(stateNotifier.value);
        },
        icon: ValueListenableBuilder<bool>(
            valueListenable: stateNotifier,
            builder: (context, on, _) {
              return Icon(
                widget.icon,
                color: on ? Theme.of(context).indicatorColor : null,
              );
            }));
  }
}
