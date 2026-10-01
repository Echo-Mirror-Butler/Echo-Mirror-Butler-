/// Shared, testable logic for normalizing a picked avatar image's file
/// extension into the MIME type the `avatars` storage bucket actually
/// allows (`image/png`, `image/jpeg` — see
/// supabase/migrations/20260526100000_issues_302_303_304_306.sql).
///
/// Building the content type by string interpolation (`'image/$ext'`) used
/// to produce `image/jpg` for `.jpg` files (not allow-listed; the bucket
/// expects `image/jpeg`) and `image/heic` for iOS Camera Roll photos (not
/// allow-listed, and not renderable by most browsers either way), so both
/// were silently rejected server-side with no useful error. See #744.
library;

/// Thrown by [normalizeAvatarContentType] when the picked file's extension
/// isn't one the `avatars` bucket accepts.
class UnsupportedAvatarFormatException implements Exception {
  UnsupportedAvatarFormatException([this.message = _defaultMessage]);

  final String message;

  @override
  String toString() => message;
}

const _defaultMessage =
    'Unsupported image format. Please use a JPEG or PNG image.';

/// Maps a file path's extension to a MIME type the `avatars` bucket allows.
/// Case-insensitive. Throws [UnsupportedAvatarFormatException] for anything
/// else (including `heic`/`heif` and files with no extension) so the caller
/// can reject client-side instead of letting Supabase storage's mime
/// allow-list reject the upload with a generic failure.
String normalizeAvatarContentType(String path) {
  final segments = path.split('.');
  final ext = segments.length > 1 ? segments.last.toLowerCase() : '';
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    default:
      throw UnsupportedAvatarFormatException();
  }
}

/// The storage file extension to use for a content type returned by
/// [normalizeAvatarContentType].
String avatarExtensionForContentType(String contentType) =>
    contentType == 'image/png' ? 'png' : 'jpg';

/// The message shown when [normalizeAvatarContentType] rejects a format.
String unsupportedAvatarMessage() => _defaultMessage;
