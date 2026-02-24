/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'package:echomirror_server_client/src/protocol/protocol.dart' as _i2;

abstract class Story implements _i1.SerializableModel {
  Story._({
    this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.imageUrls,
    required this.createdAt,
    required this.expiresAt,
    int? viewCount,
    required this.viewedBy,
    bool? isActive,
  }) : viewCount = viewCount ?? 0,
       isActive = isActive ?? true;

  factory Story({
    int? id,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
    required DateTime createdAt,
    required DateTime expiresAt,
    int? viewCount,
    required List<String> viewedBy,
    bool? isActive,
  }) = _StoryImpl;

  factory Story.fromJson(Map<String, dynamic> jsonSerialization) {
    return Story(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as String,
      userName: jsonSerialization['userName'] as String,
      userAvatarUrl: jsonSerialization['userAvatarUrl'] as String?,
      imageUrls: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['imageUrls'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      expiresAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      viewCount: jsonSerialization['viewCount'] as int,
      viewedBy: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['viewedBy'],
      ),
      isActive: jsonSerialization['isActive'] as bool,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String userId;

  String userName;

  String? userAvatarUrl;

  List<String> imageUrls;

  DateTime createdAt;

  DateTime expiresAt;

  int viewCount;

  List<String> viewedBy;

  bool isActive;

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Story copyWith({
    int? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    List<String>? viewedBy,
    bool? isActive,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Story',
      if (id != null) 'id': id,
      'userId': userId,
      'userName': userName,
      if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
      'imageUrls': imageUrls.toJson(),
      'createdAt': createdAt.toJson(),
      'expiresAt': expiresAt.toJson(),
      'viewCount': viewCount,
      'viewedBy': viewedBy.toJson(),
      'isActive': isActive,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StoryImpl extends Story {
  _StoryImpl({
    int? id,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required List<String> imageUrls,
    required DateTime createdAt,
    required DateTime expiresAt,
    int? viewCount,
    required List<String> viewedBy,
    bool? isActive,
  }) : super._(
         id: id,
         userId: userId,
         userName: userName,
         userAvatarUrl: userAvatarUrl,
         imageUrls: imageUrls,
         createdAt: createdAt,
         expiresAt: expiresAt,
         viewCount: viewCount,
         viewedBy: viewedBy,
         isActive: isActive,
       );

  /// Returns a shallow copy of this [Story]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Story copyWith({
    Object? id = _Undefined,
    String? userId,
    String? userName,
    Object? userAvatarUrl = _Undefined,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    List<String>? viewedBy,
    bool? isActive,
  }) {
    return Story(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl is String?
          ? userAvatarUrl
          : this.userAvatarUrl,
      imageUrls: imageUrls ?? this.imageUrls.map((e0) => e0).toList(),
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      viewedBy: viewedBy ?? this.viewedBy.map((e0) => e0).toList(),
      isActive: isActive ?? this.isActive,
    );
  }
}
