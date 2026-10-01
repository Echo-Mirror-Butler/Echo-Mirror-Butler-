import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:echomirror/core/utils/avatar_upload.dart';
import 'package:echomirror/core/utils/error_message_mapper.dart';

final throwsUnsupportedAvatarError = throwsA(
  isA<UnsupportedAvatarFormatException>(),
);

void main() {
  group('normalizeAvatarContentType', () {
    test('.jpg -> image/jpeg', () {
      expect(normalizeAvatarContentType('avatar.jpg'), 'image/jpeg');
    });

    test('.JPG -> image/jpeg', () {
      expect(normalizeAvatarContentType('avatar.JPG'), 'image/jpeg');
    });

    test('.jpeg -> image/jpeg', () {
      expect(normalizeAvatarContentType('avatar.jpeg'), 'image/jpeg');
    });

    test('.png -> image/png', () {
      expect(normalizeAvatarContentType('avatar.png'), 'image/png');
    });

    test('.heic is rejected client-side', () {
      expect(
        () => normalizeAvatarContentType('avatar.heic'),
        throwsUnsupportedAvatarError,
      );
    });

    test('.webp is rejected client-side', () {
      expect(
        () => normalizeAvatarContentType('avatar.webp'),
        throwsUnsupportedAvatarError,
      );
    });

    test('unknown extension is rejected client-side', () {
      expect(
        () => normalizeAvatarContentType('avatar.gif'),
        throwsUnsupportedAvatarError,
      );
    });

    test('no extension is rejected client-side', () {
      expect(
        () => normalizeAvatarContentType('avatar'),
        throwsUnsupportedAvatarError,
      );
    });
  });

  group('avatarExtensionForContentType', () {
    test('image/jpeg -> jpg', () {
      expect(avatarExtensionForContentType('image/jpeg'), 'jpg');
    });

    test('image/png -> png', () {
      expect(avatarExtensionForContentType('image/png'), 'png');
    });
  });

  group('unsupportedAvatarMessage', () {
    test('mentions PNG and JPEG', () {
      final message = unsupportedAvatarMessage();
      expect(message.toLowerCase(), contains('png'));
      expect(message.toLowerCase(), contains('jpeg'));
    });
  });

  group('friendlyErrorMessage for storage', () {
    test('mime-type rejection surfaces a specific message', () {
      final message = friendlyErrorMessage(
        StorageException('mime type image/jpg is not supported'),
      );
      expect(message.toLowerCase(), contains('not supported'));
    });

    test('network failure surfaces a connection message', () {
      final message = friendlyErrorMessage(
        StorageException('SocketException: network is unreachable'),
      );
      expect(message.toLowerCase(), contains('connect'));
    });

    test('auth failure surfaces a permission message', () {
      final message = friendlyErrorMessage(
        StorageException('Unauthorized: jwt invalid'),
      );
      expect(message.toLowerCase(), contains('permission'));
    });
  });
}
