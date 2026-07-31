import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/chat.dart';

// The chat contract: both sides derive the same conversation id, words are
// counted the way a person would count them, and the 250-word budget is a
// hard wall — at the wall, the app hands over to a phone call.
void main() {
  test('both sides derive the same chat id', () {
    expect(chatIdFor('alice', 'bob'), chatIdFor('bob', 'alice'));
    expect(chatIdFor('alice', 'bob'), 'alice_bob');
  });

  test('countWords counts human words', () {
    expect(countWords(''), 0);
    expect(countWords('   '), 0);
    expect(countWords('hi'), 1);
    expect(countWords('the gate code is 4411'), 5);
    expect(countWords('  spaced   out\n\nwords  '), 3);
  });

  test('the 250-word budget is exact', () {
    // Room left: fits exactly.
    expect(chatCanSend(248, 2), isTrue);
    expect(chatCanSend(0, chatWordCap), isTrue);
    // One word over: rejected.
    expect(chatCanSend(249, 2), isFalse);
    expect(chatCanSend(chatWordCap, 1), isFalse);
    // Empty messages never send.
    expect(chatCanSend(0, 0), isFalse);
  });
}
