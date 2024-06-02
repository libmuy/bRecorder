import 'package:flutter/material.dart';

import '../../core/service_locator.dart';
import '../../core/utils/utils.dart';
import '../../data/repository.dart';
import '../ploc/playlist_page_state.dart';
import '../widgets/editable_text.dart' as brecord;
import '../widgets/waveform/waveform.dart';


class PlaylistPage extends StatefulWidget {
  final String dirPath;
  const PlaylistPage({super.key, required this.dirPath});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final state = sl.get<PlaylistPageState>();

  @override
  void initState() {
    super.initState();
    state.init(widget.dirPath);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text("playlist title")),
          body: Container(
            color: Colors.red,
          )),
        );
  }
}
