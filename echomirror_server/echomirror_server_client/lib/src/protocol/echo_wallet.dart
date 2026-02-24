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

abstract class EchoWallet implements _i1.SerializableModel {
  EchoWallet._({
    this.id,
    required this.userId,
    required this.balance,
    required this.createdAt,
  });

  factory EchoWallet({
    int? id,
    required int userId,
    required double balance,
    required DateTime createdAt,
  }) = _EchoWalletImpl;

  factory EchoWallet.fromJson(Map<String, dynamic> jsonSerialization) {
    return EchoWallet(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      balance: (jsonSerialization['balance'] as num).toDouble(),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int userId;

  double balance;

  DateTime createdAt;

  /// Returns a shallow copy of this [EchoWallet]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  EchoWallet copyWith({
    int? id,
    int? userId,
    double? balance,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'EchoWallet',
      if (id != null) 'id': id,
      'userId': userId,
      'balance': balance,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _EchoWalletImpl extends EchoWallet {
  _EchoWalletImpl({
    int? id,
    required int userId,
    required double balance,
    required DateTime createdAt,
  }) : super._(
         id: id,
         userId: userId,
         balance: balance,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [EchoWallet]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  EchoWallet copyWith({
    Object? id = _Undefined,
    int? userId,
    double? balance,
    DateTime? createdAt,
  }) {
    return EchoWallet(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
