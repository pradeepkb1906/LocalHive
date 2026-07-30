import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// The sharing rule behind FirebaseService._shared, tested in isolation.
///
/// Firestore listeners are expensive, so one is opened per query and shared
/// between widgets. The obvious way to share — asBroadcastStream — silently
/// breaks the second widget to arrive: a broadcast stream does not replay, and
/// Firestore only pushes again when something changes. That is what left the
/// Provider Dashboard on a spinner forever while the home screen's badge, which
/// had subscribed first, showed the right count. The orders were loaded and
/// unreachable.
///
/// This reproduces the failure and then the fix, so the shape cannot quietly
/// regress. It mirrors the implementation rather than calling it, because
/// FirebaseService needs a live Firebase to construct.
void main() {
  /// The broken sharing: a plain broadcast stream.
  ({Stream<int> Function() get, void Function(int) push}) broadcastOnly() {
    final controller = StreamController<int>();
    final shared = controller.stream.asBroadcastStream();
    return (get: () => shared, push: controller.add);
  }

  /// The fix: remember the last value and hand it to whoever listens next.
  ({Stream<int> Function() get, void Function(int) push}) replayLatest() {
    final controller = StreamController<int>();
    Object? latest;
    var seen = false;
    final shared = controller.stream.map((v) {
      latest = v;
      seen = true;
      return v;
    }).asBroadcastStream();

    Stream<int> get() => Stream<int>.multi((out) {
          if (seen) out.add(latest as int);
          final sub =
              shared.listen(out.add, onError: out.addError, onDone: out.close);
          out.onCancel = sub.cancel;
        });
    return (get: get, push: controller.add);
  }

  test('a plain broadcast stream strands the second listener', () async {
    final s = broadcastOnly();
    final first = <int>[];
    s.get().listen(first.add);

    s.push(3); // the badge gets its count
    await pumpEventQueue();

    // Now the dashboard opens and listens.
    final second = <int>[];
    s.get().listen(second.add);
    await pumpEventQueue();

    expect(first, [3]);
    expect(second, isEmpty,
        reason: 'this is the bug: nothing arrives until the data changes');
  });

  test('replaying the last value serves a listener that arrives late',
      () async {
    final s = replayLatest();
    final first = <int>[];
    s.get().listen(first.add);

    s.push(3);
    await pumpEventQueue();

    final second = <int>[];
    s.get().listen(second.add);
    await pumpEventQueue();

    expect(first, [3]);
    expect(second, [3], reason: 'the dashboard sees the orders immediately');

    // And both keep receiving updates afterwards.
    s.push(4);
    await pumpEventQueue();
    expect(first, [3, 4]);
    expect(second, [3, 4]);
  });

  test('a listener before any value still waits for the first one', () async {
    final s = replayLatest();
    final seen = <int>[];
    s.get().listen(seen.add);
    await pumpEventQueue();
    expect(seen, isEmpty, reason: 'nothing to replay yet, so nothing is faked');

    s.push(7);
    await pumpEventQueue();
    expect(seen, [7]);
  });
}
