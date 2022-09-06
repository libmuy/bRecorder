import 'package:flutter/material.dart';

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
