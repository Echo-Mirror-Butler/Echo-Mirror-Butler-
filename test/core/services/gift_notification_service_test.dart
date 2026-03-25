import 'dart:async';
import 'package:echomirror/core/services/gift_notification_service.dart';
import 'package:echomirror/features/global_mirror/data/models/gift_transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GiftNotificationService', () {
    test('emits only newly inserted gift rows after initial snapshot', () async {
      final controller = StreamController<List<Map<String, dynamic>>>();
      final received = <GiftTransactionModel>[];

      final service = GiftNotificationService(
        streamFactory: (_) => controller.stream,
      );

      service.startListening('user-1', (gift) {
        received.add(gift);
      });

      controller.add([
        {
          'id': 1,
          'sender_user_id': 10,
          'recipient_user_id': 20,
          'echo_amount': 2.5,
          'created_at': '2026-03-25T10:00:00Z',
          'status': 'completed',
        },
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);

      controller.add([
        {
          'id': 1,
          'sender_user_id': 10,
          'recipient_user_id': 20,
          'echo_amount': 2.5,
          'created_at': '2026-03-25T10:00:00Z',
          'status': 'completed',
        },
        {
          'id': 2,
          'sender_user_id': 30,
          'recipient_user_id': 20,
          'echo_amount': 5.0,
          'created_at': '2026-03-25T10:01:00Z',
          'status': 'completed',
          'message': 'Great session!',
        },
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(received.length, 1);
      expect(received.first.id, 2);
      expect(received.first.echoAmount, 5.0);
      expect(received.first.message, 'Great session!');

      service.stopListening();
      await controller.close();
    });
  });
}
