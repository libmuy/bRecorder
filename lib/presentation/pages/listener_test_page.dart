import 'package:flutter/material.dart';

class ListenerTestPage extends StatefulWidget {
  const ListenerTestPage({Key? key}) : super(key: key);

  @override
  State<ListenerTestPage> createState() => _ListenerTestPageState();
}

class _ListenerTestPageState extends State<ListenerTestPage> {
  int _downCounter = 0;
  int _upCounter = 0;
  double x = 0.0;
  double y = 0.0;

  void _incrementDown(PointerEvent details) {
    _updateLocation(details);
    setState(() {
      _downCounter++;
    });
  }

  void _incrementUp(PointerEvent details) {
    _updateLocation(details);
    setState(() {
      _upCounter++;
    });
  }

  void _updateLocation(PointerEvent details) {
    setState(() {
      x = details.position.dx;
      y = details.position.dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Listener(
        onPointerDown: _incrementDown,
        onPointerMove: _updateLocation,
        onPointerUp: _incrementUp,
        child: Container(
          color: Colors.lightBlueAccent,
          child: Column(
            children: <Widget>[
              Text(
                '$_downCounter presses\n$_upCounter releases',
                style: Theme.of(context).textTheme.headline4,
              ),
              Text(
                'The cursor is here: (${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})',
                style: Theme.of(context).textTheme.headline4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
