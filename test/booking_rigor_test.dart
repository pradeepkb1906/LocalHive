import 'package:flutter_test/flutter_test.dart';
import 'package:localhive/models/data.dart';

// The ordering-app rigor pass: every booking knows when it was placed and
// whether it is still moving. These are the two facts the Bookings screen's
// In progress / Past split and the "Placed …" line hang off.
void main() {
  Booking withStatus(String status, {DateTime? at}) =>
      Booking('Taco Truck', '2 items', status, 21.50, createdAt: at);

  test('active statuses stay in the In progress section', () {
    for (final s in [
      'Placed',
      'Requested',
      'Accepted',
      'Preparing',
      'Ready',
      'Out for delivery',
      'Confirmed',
    ]) {
      expect(withStatus(s).isActive, isTrue, reason: '$s should be active');
    }
  });

  test('settled statuses fall into Past', () {
    for (final s in ['Completed', 'Delivered', 'Declined', 'Cancelled']) {
      expect(withStatus(s).isActive, isFalse, reason: '$s should be past');
    }
  });

  test('a booking can be cancelled only while it is still Requested', () {
    Booking saved(String status) =>
        Booking('Maria G.', 'Cleaning · 3 hrs', status, 84, id: 'bk1');
    expect(saved('Requested').canCancel, isTrue);
    for (final s in ['Accepted', 'Completed', 'Declined', 'Cancelled']) {
      expect(saved(s).canCancel, isFalse,
          reason: '$s is past the cancellation window');
    }
    // A row with no Firestore id (mock data) has nothing to cancel.
    expect(withStatus('Requested').canCancel, isFalse);
  });

  test('placedLabel is empty when no timestamp was recorded', () {
    expect(withStatus('Placed').placedLabel, isEmpty);
  });

  test('a booking placed today reads "Placed today"', () {
    final now = DateTime.now();
    final label =
        withStatus('Placed', at: DateTime(now.year, now.month, now.day, 19, 5))
            .placedLabel;
    expect(label, startsWith('Placed today'));
    expect(label, contains('7:05 PM'));
  });

  test('an older booking reads a real calendar date, not "today"', () {
    final label =
        withStatus('Delivered', at: DateTime(2026, 7, 4, 9, 30)).placedLabel;
    expect(label, contains('Jul 4'));
    expect(label, contains('9:30 AM'));
    expect(label, isNot(contains('today')));
  });
}
