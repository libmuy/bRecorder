import 'package:brecorder/core/logging.dart';

final log = Logger('BrowserViewDelegate');

class BrowserViewDelegate {
  void Function(bool)? setEditModeFunc;
  void setEditMode(bool edit) {
    if (setEditModeFunc != null) {
      setEditModeFunc!(edit);
    }
  }
}
