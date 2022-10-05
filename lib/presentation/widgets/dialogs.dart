import 'package:flutter/material.dart';

import '../../core/global_info.dart';
import '../../core/logging.dart';
import '../../domain/entities.dart';
import 'folder_selector.dart';

const _kBorderRadius = GlobalInfo.kDialogBorderRadius;

final log = Logger('Dialogs', level: LogLevel.debug);

void showNewFolderDialog(
    BuildContext context, void Function(String path) folderNotifier) {
  String currentValue = "";
  showDialog(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('New Folder'),
      content: TextField(
        onChanged: (value) {
          currentValue = value;
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            folderNotifier(currentValue);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showFolderSelecter(
    BuildContext context, void Function(FolderInfo folder) onFolderSelected) {
  showModalBottomSheet<void>(
    elevation: 20,
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(_kBorderRadius),
        topRight: Radius.circular(_kBorderRadius),
      ),
    ),
    builder: (BuildContext context) {
      return SizedBox(
          height: 400,
          // color: Colors.amber,
          child: FolderSelector(
            onFolderSelected: onFolderSelected,
          ));
    },
  );
}

Future<dynamic> showAudioItemSortDialog(BuildContext context,
    {required String title, required Map<String, dynamic> options}) {
  const kSortDialogOptionPadding = 15.0;
  const kSortDialogOptionDivider = Divider(
    height: 0.5,
    thickness: 0.5,
  );
  List<Widget> children = [];
  List<GlobalKey> optionKeys = [];
  List<dynamic> optionReturn = [];
  List<ValueNotifier<bool>> optionHighlights = [];
  var selectedIndex = -1;

  int hitTest(Offset position) {
    for (var key in optionKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final local = box.globalToLocal(position);
      final x = local.dx;
      final y = local.dy;
      final w = box.size.width;
      final h = box.size.height;

      if (x > 0 && x < w && y > 0 && y < h) {
        return optionKeys.indexOf(key);
      }
    }

    return -1;
  }

  void setHighlight(int index) {
    final len = optionHighlights.length;
    selectedIndex = index;
    for (var i = 0; i < len; i++) {
      if (index == i) {
        optionHighlights[i].value = true;
      } else {
        optionHighlights[i].value = false;
      }
    }
  }

  void addOption(String title, dynamic returnValue) {
    final optionKey = GlobalKey();
    final optionHighlightNotifier = ValueNotifier(false);
    children.add(ValueListenableBuilder<bool>(
        valueListenable: optionHighlightNotifier,
        builder: ((context, isHighlight, _) {
          return Container(
              color: isHighlight
                  ? Theme.of(context).highlightColor
                  : Colors.transparent,
              key: optionKey,
              padding: const EdgeInsets.all(kSortDialogOptionPadding),
              alignment: Alignment.center,
              child: Text(
                title,
                style: const TextStyle(fontSize: 20),
              ));
        })));
    children.add(kSortDialogOptionDivider);
    optionKeys.add(optionKey);
    optionHighlights.add(optionHighlightNotifier);
    optionReturn.add(returnValue);
  }

  return showModalBottomSheet<dynamic>(
    clipBehavior: Clip.antiAlias,
    enableDrag: false,
    constraints:
        BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 15),
    backgroundColor: Colors.transparent,
    elevation: 20,
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(_kBorderRadius),
      ),
    ),
    builder: (BuildContext context) {
      // ========= INITIALIZATION =========
      children = [];
      optionKeys = [];
      optionReturn = [];
      optionHighlights = [];
      selectedIndex = -1;

      // ========= TITLE =========
      children.add(Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(kSortDialogOptionPadding * 0.7),
        child: Text(
          title,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 15),
        ),
      ));
      children.add(kSortDialogOptionDivider);

      // ========= OPTIONS =========
      options.forEach(
        (key, value) => addOption(key, value),
      );

      // ========= CANCEL =========
      addOption("Cancel", null);
      children.removeLast(); //remove diriver
      final cancel = children.removeLast();

      // ========= Wrapper =========
      return GestureDetector(
        onVerticalDragStart: (details) {
          final hitted = hitTest(details.globalPosition);
          setHighlight(hitted);
          log.debug("onVerticalDragStart: $hitted");
        },
        onVerticalDragEnd: (details) {
          log.debug("onVerticalDragEnd: ");
          if (selectedIndex >= 0) {
            Navigator.pop(context, optionReturn[selectedIndex]);
          }
        },
        onVerticalDragCancel: () {
          log.debug("onVerticalDragCancel:");
        },
        onVerticalDragUpdate: (details) {
          final hitted = hitTest(details.globalPosition);
          setHighlight(hitted);
          log.debug("onVerticalDragUpdate: $hitted");
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                // color: Colors.black,
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(_kBorderRadius),
                    topRight: Radius.circular(_kBorderRadius),
                    bottomLeft: Radius.circular(_kBorderRadius),
                    bottomRight: Radius.circular(_kBorderRadius)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  // color: Colors.black,
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(_kBorderRadius),
                      topRight: Radius.circular(_kBorderRadius),
                      bottomLeft: Radius.circular(_kBorderRadius),
                      bottomRight: Radius.circular(_kBorderRadius)),
                ),
                child: cancel)
          ],
        ),
      );
    },
  );
}
