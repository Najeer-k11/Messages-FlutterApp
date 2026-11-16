// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_state_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetReadStateModelCollection on Isar {
  IsarCollection<ReadStateModel> get readStateModels => this.collection();
}

const ReadStateModelSchema = CollectionSchema(
  name: r'ReadStateModel',
  id: 8339079175478420442,
  properties: {
    r'address': PropertySchema(id: 0, name: r'address', type: IsarType.string),
    r'readUpTo': PropertySchema(
      id: 1,
      name: r'readUpTo',
      type: IsarType.dateTime,
    ),
    r'unreadFrom': PropertySchema(
      id: 2,
      name: r'unreadFrom',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _readStateModelEstimateSize,
  serialize: _readStateModelSerialize,
  deserialize: _readStateModelDeserialize,
  deserializeProp: _readStateModelDeserializeProp,
  idName: r'id',
  indexes: {
    r'address': IndexSchema(
      id: -259407546592846288,
      name: r'address',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'address',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _readStateModelGetId,
  getLinks: _readStateModelGetLinks,
  attach: _readStateModelAttach,
  version: '3.4.1',
);

int _readStateModelEstimateSize(
  ReadStateModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.address.length * 3;
  return bytesCount;
}

void _readStateModelSerialize(
  ReadStateModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.address);
  writer.writeDateTime(offsets[1], object.readUpTo);
  writer.writeDateTime(offsets[2], object.unreadFrom);
}

ReadStateModel _readStateModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReadStateModel();
  object.address = reader.readString(offsets[0]);
  object.id = id;
  object.readUpTo = reader.readDateTimeOrNull(offsets[1]);
  object.unreadFrom = reader.readDateTimeOrNull(offsets[2]);
  return object;
}

P _readStateModelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _readStateModelGetId(ReadStateModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _readStateModelGetLinks(ReadStateModel object) {
  return [];
}

void _readStateModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  ReadStateModel object,
) {
  object.id = id;
}

extension ReadStateModelByIndex on IsarCollection<ReadStateModel> {
  Future<ReadStateModel?> getByAddress(String address) {
    return getByIndex(r'address', [address]);
  }

  ReadStateModel? getByAddressSync(String address) {
    return getByIndexSync(r'address', [address]);
  }

  Future<bool> deleteByAddress(String address) {
    return deleteByIndex(r'address', [address]);
  }

  bool deleteByAddressSync(String address) {
    return deleteByIndexSync(r'address', [address]);
  }

  Future<List<ReadStateModel?>> getAllByAddress(List<String> addressValues) {
    final values = addressValues.map((e) => [e]).toList();
    return getAllByIndex(r'address', values);
  }

  List<ReadStateModel?> getAllByAddressSync(List<String> addressValues) {
    final values = addressValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'address', values);
  }

  Future<int> deleteAllByAddress(List<String> addressValues) {
    final values = addressValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'address', values);
  }

  int deleteAllByAddressSync(List<String> addressValues) {
    final values = addressValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'address', values);
  }

  Future<Id> putByAddress(ReadStateModel object) {
    return putByIndex(r'address', object);
  }

  Id putByAddressSync(ReadStateModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'address', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAddress(List<ReadStateModel> objects) {
    return putAllByIndex(r'address', objects);
  }

  List<Id> putAllByAddressSync(
    List<ReadStateModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'address', objects, saveLinks: saveLinks);
  }
}

extension ReadStateModelQueryWhereSort
    on QueryBuilder<ReadStateModel, ReadStateModel, QWhere> {
  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReadStateModelQueryWhere
    on QueryBuilder<ReadStateModel, ReadStateModel, QWhereClause> {
  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause>
  addressEqualTo(String address) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'address', value: [address]),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterWhereClause>
  addressNotEqualTo(String address) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'address',
                lower: [],
                upper: [address],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'address',
                lower: [address],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'address',
                lower: [address],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'address',
                lower: [],
                upper: [address],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ReadStateModelQueryFilter
    on QueryBuilder<ReadStateModel, ReadStateModel, QFilterCondition> {
  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'address',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'address',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'address',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'address', value: ''),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  addressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'address', value: ''),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'readUpTo'),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'readUpTo'),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'readUpTo', value: value),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'readUpTo',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'readUpTo',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  readUpToBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'readUpTo',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'unreadFrom'),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'unreadFrom'),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unreadFrom', value: value),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unreadFrom',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unreadFrom',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterFilterCondition>
  unreadFromBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unreadFrom',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReadStateModelQueryObject
    on QueryBuilder<ReadStateModel, ReadStateModel, QFilterCondition> {}

extension ReadStateModelQueryLinks
    on QueryBuilder<ReadStateModel, ReadStateModel, QFilterCondition> {}

extension ReadStateModelQuerySortBy
    on QueryBuilder<ReadStateModel, ReadStateModel, QSortBy> {
  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> sortByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  sortByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> sortByReadUpTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readUpTo', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  sortByReadUpToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readUpTo', Sort.desc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  sortByUnreadFrom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadFrom', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  sortByUnreadFromDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadFrom', Sort.desc);
    });
  }
}

extension ReadStateModelQuerySortThenBy
    on QueryBuilder<ReadStateModel, ReadStateModel, QSortThenBy> {
  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> thenByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  thenByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy> thenByReadUpTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readUpTo', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  thenByReadUpToDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readUpTo', Sort.desc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  thenByUnreadFrom() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadFrom', Sort.asc);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QAfterSortBy>
  thenByUnreadFromDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unreadFrom', Sort.desc);
    });
  }
}

extension ReadStateModelQueryWhereDistinct
    on QueryBuilder<ReadStateModel, ReadStateModel, QDistinct> {
  QueryBuilder<ReadStateModel, ReadStateModel, QDistinct> distinctByAddress({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'address', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QDistinct> distinctByReadUpTo() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'readUpTo');
    });
  }

  QueryBuilder<ReadStateModel, ReadStateModel, QDistinct>
  distinctByUnreadFrom() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unreadFrom');
    });
  }
}

extension ReadStateModelQueryProperty
    on QueryBuilder<ReadStateModel, ReadStateModel, QQueryProperty> {
  QueryBuilder<ReadStateModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReadStateModel, String, QQueryOperations> addressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'address');
    });
  }

  QueryBuilder<ReadStateModel, DateTime?, QQueryOperations> readUpToProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'readUpTo');
    });
  }

  QueryBuilder<ReadStateModel, DateTime?, QQueryOperations>
  unreadFromProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unreadFrom');
    });
  }
}
