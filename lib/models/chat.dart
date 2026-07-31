/// In-app 1:1 messaging between the people on either side of an order:
/// customer ↔ business owner, customer ↔ delivery partner. Text only, and
/// deliberately short — a conversation gets [chatWordCap] words in total
/// (both sides combined); after that the app says "place a call" and offers
/// the number when it has one. Chat is for "gate code is 4411", not for
/// negotiations.

/// Total words a conversation may contain before the composer locks.
const chatWordCap = 250;

/// Words in [text] the way a person would count them: whitespace-separated
/// tokens, empty text counting zero.
int countWords(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

/// The id both sides derive independently for their shared conversation:
/// the two uids, sorted, joined — so whoever opens the chat first creates
/// the same document the other will find.
String chatIdFor(String a, String b) {
  final pair = [a, b]..sort();
  return '${pair[0]}_${pair[1]}';
}

/// Whether a new message of [messageWords] fits under the cap given
/// [usedWords] already in the conversation.
bool chatCanSend(int usedWords, int messageWords) =>
    messageWords > 0 && usedWords + messageWords <= chatWordCap;
