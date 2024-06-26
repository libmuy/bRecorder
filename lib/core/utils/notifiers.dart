import 'package:flutter/foundation.dart';

import 'utils.dart';

class SimpleNotifier extends ChangeNotifier {
  SimpleNotifier();

  void notify() => notifyListeners();
}

class GlobalModeNotifier extends ChangeNotifier
    implements ValueListenable<GlobalMode> {
  GlobalModeNotifier(this._value);

  @override
  GlobalMode get value => _value;
  GlobalMode _value;

  set value(GlobalMode newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }
}

class ForcibleValueNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  ForcibleValueNotifier(this._value);

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced with something that is not equal to the old
  /// value as evaluated by the equality operator ==, this class notifies its
  /// listeners.
  @override
  T get value => _value;
  T _value;
  set value(T newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';

  void update(
      {required T newValue,
      bool forceNotify = false,
      bool forceNotNotify = false}) {
    assert(!(forceNotNotify && forceNotify));

    if (forceNotify) {
      _value = newValue;
      notifyListeners();
    } else if (forceNotNotify) {
      _value = newValue;
    } else {
      if (newValue != null) value = newValue;
    }
  }

  void notify() => notifyListeners();
}

/// return [shouldCallNext]
/// if [shouldCallNext] is false will not call
typedef PriorityValueCallback = bool Function();

class _ListenerEntry {
  int priority;
  PriorityValueCallback callback;
  _ListenerEntry(this.priority, this.callback);
}

class PriorityValueNotifier<T> {
  PriorityValueNotifier(this._value);

  T get value => _value;
  T _value;
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';

  List<_ListenerEntry> _listeners = [];
  bool _debugDisposed = false;

  bool _debugAssertNotDisposed() {
    assert(() {
      if (_debugDisposed) {
        throw FlutterError(
          'A $runtimeType was used after being disposed.\n'
          'Once you have called dispose() on a $runtimeType, it can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }

  void addListener(int priority, PriorityValueCallback listener) {
    assert(_debugAssertNotDisposed());
    _listeners.add(_ListenerEntry(priority, listener));
    _listeners.sort(((a, b) => a.priority.compareTo(b.priority)));
  }

  void removeListener(int priority, PriorityValueCallback listener) {
    for (int i = 0; i < _listeners.length; i++) {
      final entry = _listeners[i];
      if (entry.priority == priority && entry.callback == listener) {
        _listeners.remove(entry);
        break;
      }
    }
  }

  @mustCallSuper
  void dispose() {
    assert(_debugAssertNotDisposed());
    assert(() {
      _debugDisposed = true;
      return true;
    }());
    _listeners = [];
  }

  @protected
  @visibleForTesting
  @pragma('vm:notify-debugger-on-exception')
  void notifyListeners() {
    assert(_debugAssertNotDisposed());
    if (_listeners.isEmpty) return;

    for (int i = 0; i < _listeners.length; i++) {
      final next = _listeners[i].callback();
      if (!next) break;
    }
  }
}
