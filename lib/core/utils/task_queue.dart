/// reference: https://stackoverflow.com/questions/62878704/how-to-implement-an-async-task-queue-with-multiple-concurrent-workers-async-in
import 'dart:async';
import 'dart:collection';

import '../logging.dart';

final log = Logger('TaskQueue', level: LogLevel.debug);

class TaskQueue {
  final Queue<Task> _queue = Queue();
  // final StreamController<B> _streamController = StreamController();

  final int maxConcurrentTasks;
  int runningTasks = 0;
  Task? _current;

  TaskQueue({this.maxConcurrentTasks = 128});

  // Stream<B> get stream => _streamController.stream;

  void add(Task t) {
    log.debug("add task");
    _queue.add(t);
    if (_current == null) _startExecution();
  }

  void cancelAll() async {
    _queue.clear();
    _current?.cancel?.call();
  }

  void replaceAll(Task t) {
    cancelAll();
    add(t);
  }

  Future<void> _startExecution() async {
    if (runningTasks == maxConcurrentTasks || _queue.isEmpty) {
      return;
    }

    while (_queue.isNotEmpty && runningTasks < maxConcurrentTasks) {
      runningTasks++;
      // print('Concurrent workers: $runningTasks');
      log.debug("execute task: Start");
      _current = _queue.removeFirst();
      await _current!.runTask();
      _current = null;
      log.debug("execute task: End");
      runningTasks--;
      // task(_queue.removeFirst()).then((value) async {
      //   // _streamController.add(value);

      //   while (_queue.isNotEmpty) {
      //     // _streamController.add(await task(_input.removeFirst()));
      //   }

      //   runningTasks--;
      //   print('Concurrent workers: $runningTasks');
      // });
    }
  }
}

class Task {
  final dynamic data;
  final Future<void> Function(dynamic data) func;
  final void Function()? cancel;

  Task(this.func, {this.data, this.cancel});

  Future<void> runTask() async {
    await func(data);
  }

  void cancelTask() {
    cancel?.call();
  }
}


// Random _rnd = Random();
// Future<List<String>> crawl(String x) =>
//     Future.delayed(Duration(seconds: _rnd.nextInt(5)), () => x.split('-'));

// void main() {
//   final runner = TaskRunner(crawl, maxConcurrentTasks: 3);

//   runner.stream.forEach((listOfString) {
//     if (listOfString.length == 1) {
//       print('DONE: ${listOfString.first}');
//     } else {
//       print('PUTTING STRINGS ON QUEUE: $listOfString');
//       runner.addAll(listOfString);
//     }
//   });

//   runner.addAll(['1-2-3-4-5-6-7-8-9', '10-20-30-40-50-60-70-80-90']);
// }