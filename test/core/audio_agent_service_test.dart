import 'package:bb_recorder/core/audio_agent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("test android audio agent, get duration", () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AudioServiceAgent agent = AudioServiceAgent();
    final result = await agent.getDuration("/");

    expect(result, 101);
  });
}
