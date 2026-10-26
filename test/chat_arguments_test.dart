import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `ChatScreen` call site must pass the argument keys `ChatController`
/// actually reads.
///
/// This is a source test rather than a widget test because the bug it guards
/// is a *spelling* bug, and it shipped: the cab screens were passing the
/// multi-vendor set - `customerName`, `restaurantId`, `customerProfileImage` -
/// while the controller reads `senderName`, `receivedId`, `senderProfileUrl`.
/// The driver's controller then threw part way through reading them, leaving
/// the screen with no receiver and a Send button that addressed nobody. The
/// client reported it as "cant chat also".
///
/// Nothing about the types involved could catch that: `Get.arguments` is
/// `dynamic` and a map literal accepts any key. So the check is on the text.
void main() {
  final Directory lib = Directory('lib');

  /// The keys the controller reads and cannot work without.
  const List<String> required = <String>[
    'orderId',
    'senderId',
    'senderName',
    'receivedId',
    'receivedName',
    'chatType',
  ];

  /// Keys that mean this call site was written against the wrong controller.
  const List<String> forbidden = <String>[
    'customerName',
    'restaurantName',
    'restaurantId',
    'customerId',
    'customerProfileImage',
    'restaurantProfileImage',
  ];

  List<({String file, int line, String body})> chatCallSites() {
    final List<({String file, int line, String body})> found = <({String file, int line, String body})>[];
    for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Commented-out code is not a call site. The apps carry a fair amount of
      // it, including a `ChatScreen` block from a different product entirely.
      final String source = entity
          .readAsStringSync()
          .split('\n')
          .map((String line) => line.trimLeft().startsWith('//') ? '' : line)
          .join('\n');
      // Every call site in both apps is written as `ChatScreen(), arguments: {`
      // possibly across a line break, followed by a map literal.
      final RegExp pattern = RegExp(r'ChatScreen\(\)\s*,\s*arguments:\s*(?:<String,\s*dynamic>)?\s*\{');
      for (final RegExpMatch match in pattern.allMatches(source)) {
        int depth = 0;
        int end = match.end - 1;
        for (int i = match.end - 1; i < source.length; i++) {
          if (source[i] == '{') depth++;
          if (source[i] == '}') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        found.add((
          file: entity.path,
          line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
          body: source.substring(match.end, end),
        ));
      }
    }
    return found;
  }

  test('every ChatScreen call site passes the keys the controller reads', () {
    final List<({String file, int line, String body})> sites = chatCallSites();
    expect(sites, isNotEmpty, reason: 'the scan itself must not silently find nothing');

    for (final ({String file, int line, String body}) site in sites) {
      for (final String key in required) {
        expect(
          site.body.contains('"$key"') || site.body.contains("'$key'"),
          isTrue,
          reason: '${site.file}:${site.line} does not pass "$key"',
        );
      }
    }
  });

  test('no ChatScreen call site uses the multi-vendor argument names', () {
    for (final ({String file, int line, String body}) site in chatCallSites()) {
      for (final String key in forbidden) {
        expect(
          site.body.contains('"$key":') || site.body.contains("'$key':"),
          isFalse,
          reason: '${site.file}:${site.line} passes "$key", which ChatController never reads',
        );
      }
    }
  });

  test('senderId and receivedId are never the same expression', () {
    // The customer ride-history screen shipped with `senderId: driverUser?.id`
    // and no `receivedId` at all - the two roles had been swapped by hand.
    final RegExp sender = RegExp(r'''["']senderId["']\s*:\s*([^,\n]+)''');
    final RegExp received = RegExp(r'''["']receivedId["']\s*:\s*([^,\n]+)''');
    for (final ({String file, int line, String body}) site in chatCallSites()) {
      final String? a = sender.firstMatch(site.body)?.group(1)?.trim();
      final String? b = received.firstMatch(site.body)?.group(1)?.trim();
      expect(a, isNotNull, reason: '${site.file}:${site.line}');
      expect(b, isNotNull, reason: '${site.file}:${site.line}');
      expect(a, isNot(b), reason: '${site.file}:${site.line} sends the chat to itself');
    }
  });
}
