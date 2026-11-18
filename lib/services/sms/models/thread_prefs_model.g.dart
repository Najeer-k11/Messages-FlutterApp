// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'thread_prefs_model.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetThreadPrefsModelCollection on Isar {
  IsarCollection<ThreadPrefsModel> get threadPrefsModels => this.collection();
}

const ThreadPrefsModelSchema = CollectionSchema(
  name: r'ThreadPrefsModel',
  id: -8439731622103208720,
  properties: {
    r'address': PropertySchema(id: 0, name: r'address', type: IsarType.string),
    r'archivedAt': PropertySchema(
      id: 1,
      name: r'archivedAt',
      type: IsarType.dateTime,
    ),
    r'draft': PropertySchema(id: 2, name: r'draft', type: IsarType.string),
    r'muted': PropertySchema(id: 3, name: r'muted', type: IsarType.bool),
    r'pinnedAt': PropertySchema(
      id: 4,
      name: r'pinnedAt',
      type: IsarType.dateTime,
    ),
    r'spam': PropertySchema(id: 5, name: r'spam', type: IsarType.bool),
  },

  estimateSize: _threadPrefsModelEstimateSize,
  serialize: _threadPrefsModelSerialize,
  deserialize: _threadPrefsModelDeserialize,
  deserializeProp: _threadPrefsModelDeserializeProp,
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

  getId: _threadPrefsModelGetId,
  getLinks: _threadPrefsModelGetLinks,
  attach: _threadPrefsModelAttach,
  version: '3.4.1',
);

int _threadPrefsModelEstimateSize(
  ThreadPrefsModel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.address.length * 3;
  bytesCount += 3 + object.draft.length * 3;
  return bytesCount;
}

void _threadPrefsModelSerialize(
  ThreadPrefsModel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.address);
  writer.writeDateTime(offsets[1], object.archivedAt);
  writer.writeString(offsets[2], object.draft);
  writer.writeBool(offsets[3], object.muted);
  writer.writeDateTime(offsets[4], object.pinnedAt);
  writer.writeBool(offsets[5], object.spam);
}

ThreadPrefsModel _threadPrefsModelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ThreadPrefsModel();
  object.address = reader.readString(offsets[0]);
  object.archivedAt = reader.readDateTimeOrNull(offsets[1]);
  object.draft = reader.readString(offsets[2]);
  object.id = id;
  object.muted = reader.readBool(offsets[3]);
  object.pinnedAt = reader.readDateTimeOrNull(offsets[4]);
  object.spam = reader.readBool(offsets[5]);
  return object;
}

P _threadPrefsModelDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _threadPrefsModelGetId(ThreadPrefsModel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _threadPrefsModelGetLinks(ThreadPrefsModel object) {
  return [];
}

void _threadPrefsModelAttach(
  IsarCollection<dynamic> col,
  Id id,
  ThreadPrefsModel object,
) {
  object.id = id;
}

extension ThreadPrefsModelByIndex on IsarCollection<ThreadPrefsModel> {
  Future<ThreadPrefsModel?> getByAddress(String address) {
    return getByIndex(r'address', [address]);
  }

  ThreadPrefsModel? getByAddressSync(String address) {
    return getByIndexSync(r'address', [address]);
  }

  Future<bool> deleteByAddress(String address) {
    return deleteByIndex(r'address', [address]);
  }

  bool deleteByAddressSync(String address) {
    return deleteByIndexSync(r'address', [address]);
  }

  Future<List<ThreadPrefsModel?>> getAllByAddress(List<String> addressValues) {
    final values = addressValues.map((e) => [e]).toList();
    return getAllByIndex(r'address', values);
  }

  List<ThreadPrefsModel?> getAllByAddressSync(List<String> addressValues) {
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

  Future<Id> putByAddress(ThreadPrefsModel object) {
    return putByIndex(r'address', object);
  }

  Id putByAddressSync(ThreadPrefsModel object, {bool saveLinks = true}) {
    return putByIndexSync(r'address', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByAddress(List<ThreadPrefsModel> objects) {
    return putAllByIndex(r'address', objects);
  }

  List<Id> putAllByAddressSync(
    List<ThreadPrefsModel> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'address', objects, saveLinks: saveLinks);
  }
}

extension ThreadPrefsModelQueryWhereSort
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QWhere> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ThreadPrefsModelQueryWhere
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QWhereClause> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause> idBetween(
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause>
  addressEqualTo(String address) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'address', value: [address]),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterWhereClause>
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

extension ThreadPrefsModelQueryFilter
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QFilterCondition> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  addressIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'address', value: ''),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  addressIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'address', value: ''),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'archivedAt'),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'archivedAt'),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'archivedAt', value: value),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'archivedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'archivedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  archivedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'archivedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'draft',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'draft',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'draft',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'draft', value: ''),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  draftIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'draft', value: ''),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  idBetween(
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

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  mutedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'muted', value: value),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'pinnedAt'),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'pinnedAt'),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pinnedAt', value: value),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pinnedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pinnedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  pinnedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pinnedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterFilterCondition>
  spamEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'spam', value: value),
      );
    });
  }
}

extension ThreadPrefsModelQueryObject
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QFilterCondition> {}

extension ThreadPrefsModelQueryLinks
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QFilterCondition> {}

extension ThreadPrefsModelQuerySortBy
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QSortBy> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByArchivedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> sortByDraft() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByDraftDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> sortByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByMutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByPinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinnedAt', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortByPinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinnedAt', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> sortBySpam() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spam', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  sortBySpamDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spam', Sort.desc);
    });
  }
}

extension ThreadPrefsModelQuerySortThenBy
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QSortThenBy> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByAddress() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByAddressDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'address', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByArchivedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> thenByDraft() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByDraftDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'draft', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> thenByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByMutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'muted', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByPinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinnedAt', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenByPinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pinnedAt', Sort.desc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy> thenBySpam() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spam', Sort.asc);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QAfterSortBy>
  thenBySpamDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'spam', Sort.desc);
    });
  }
}

extension ThreadPrefsModelQueryWhereDistinct
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct> {
  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct>
  distinctByAddress({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'address', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct>
  distinctByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'archivedAt');
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct> distinctByDraft({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'draft', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct>
  distinctByMuted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'muted');
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct>
  distinctByPinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pinnedAt');
    });
  }

  QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QDistinct> distinctBySpam() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'spam');
    });
  }
}

extension ThreadPrefsModelQueryProperty
    on QueryBuilder<ThreadPrefsModel, ThreadPrefsModel, QQueryProperty> {
  QueryBuilder<ThreadPrefsModel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ThreadPrefsModel, String, QQueryOperations> addressProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'address');
    });
  }

  QueryBuilder<ThreadPrefsModel, DateTime?, QQueryOperations>
  archivedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'archivedAt');
    });
  }

  QueryBuilder<ThreadPrefsModel, String, QQueryOperations> draftProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'draft');
    });
  }

  QueryBuilder<ThreadPrefsModel, bool, QQueryOperations> mutedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'muted');
    });
  }

  QueryBuilder<ThreadPrefsModel, DateTime?, QQueryOperations>
  pinnedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pinnedAt');
    });
  }

  QueryBuilder<ThreadPrefsModel, bool, QQueryOperations> spamProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'spam');
    });
  }
}
