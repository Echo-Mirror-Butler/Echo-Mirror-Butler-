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

abstract class GiftTransaction implements _i1.SerializableModel {
  GiftTransaction._({
    this.id,
    required this.senderUserId,
    required this.recipientUserId,
    required this.echoAmount,
    required this.createdAt,
    required this.status,
    this.stellarTxHash,
    this.message,
  });

  factory GiftTransaction({
    int? id,
    required int senderUserId,
    required int recipientUserId,
    required double echoAmount,
    required DateTime createdAt,
    required String status,
    String? stellarTxHash,
    String? message,
  }) = _GiftTransactionImpl;

  factory GiftTransaction.fromJson(Map<String, dynamic> jsonSerialization) {
    return GiftTransaction(
      id: jsonSerialization['id'] as int?,
      senderUserId: jsonSerialization['senderUserId'] as int,
      recipientUserId: jsonSerialization['recipientUserId'] as int,
      echoAmount: (jsonSerialization['echoAmount'] as num).toDouble(),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      status: jsonSerialization['status'] as String,
      stellarTxHash: jsonSerialization['stellarTxHash'] as String?,
      message: jsonSerialization['message'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int senderUserId;

  int recipientUserId;

  double echoAmount;

  DateTime createdAt;

  String status;

  String? stellarTxHash;

  String? message;

  /// Returns a shallow copy of this [GiftTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  GiftTransaction copyWith({
    int? id,
    int? senderUserId,
    int? recipientUserId,
    double? echoAmount,
    DateTime? createdAt,
    String? status,
    String? stellarTxHash,
    String? message,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'GiftTransaction',
      if (id != null) 'id': id,
      'senderUserId': senderUserId,
      'recipientUserId': recipientUserId,
      'echoAmount': echoAmount,
      'createdAt': createdAt.toJson(),
      'status': status,
      if (stellarTxHash != null) 'stellarTxHash': stellarTxHash,
      if (message != null) 'message': message,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _GiftTransactionImpl extends GiftTransaction {
  _GiftTransactionImpl({
    int? id,
    required int senderUserId,
    required int recipientUserId,
    required double echoAmount,
    required DateTime createdAt,
    required String status,
    String? stellarTxHash,
    String? message,
  }) : super._(
         id: id,
         senderUserId: senderUserId,
         recipientUserId: recipientUserId,
         echoAmount: echoAmount,
         createdAt: createdAt,
         status: status,
         stellarTxHash: stellarTxHash,
         message: message,
       );

  /// Returns a shallow copy of this [GiftTransaction]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  GiftTransaction copyWith({
    Object? id = _Undefined,
    int? senderUserId,
    int? recipientUserId,
    double? echoAmount,
    DateTime? createdAt,
    String? status,
    Object? stellarTxHash = _Undefined,
    Object? message = _Undefined,
  }) {
    return GiftTransaction(
      id: id is int? ? id : this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      echoAmount: echoAmount ?? this.echoAmount,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      stellarTxHash: stellarTxHash is String?
          ? stellarTxHash
          : this.stellarTxHash,
      message: message is String? ? message : this.message,
    );
  }
}
