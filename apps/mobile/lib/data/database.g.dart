// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CurrenciesTable extends Currencies
    with TableInfo<$CurrenciesTable, CurrencyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrenciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _mainMeta = const VerificationMeta('main');
  @override
  late final GeneratedColumn<bool> main = GeneratedColumn<bool>(
    'main',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("main" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [code, enabled, main];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CurrencyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('main')) {
      context.handle(
        _mainMeta,
        main.isAcceptableOrUnknown(data['main']!, _mainMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  CurrencyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CurrencyRow(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      main: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}main'],
      )!,
    );
  }

  @override
  $CurrenciesTable createAlias(String alias) {
    return $CurrenciesTable(attachedDatabase, alias);
  }
}

class CurrencyRow extends DataClass implements Insertable<CurrencyRow> {
  final String code;
  final bool enabled;
  final bool main;
  const CurrencyRow({
    required this.code,
    required this.enabled,
    required this.main,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['enabled'] = Variable<bool>(enabled);
    map['main'] = Variable<bool>(main);
    return map;
  }

  CurrenciesCompanion toCompanion(bool nullToAbsent) {
    return CurrenciesCompanion(
      code: Value(code),
      enabled: Value(enabled),
      main: Value(main),
    );
  }

  factory CurrencyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CurrencyRow(
      code: serializer.fromJson<String>(json['code']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      main: serializer.fromJson<bool>(json['main']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'enabled': serializer.toJson<bool>(enabled),
      'main': serializer.toJson<bool>(main),
    };
  }

  CurrencyRow copyWith({String? code, bool? enabled, bool? main}) =>
      CurrencyRow(
        code: code ?? this.code,
        enabled: enabled ?? this.enabled,
        main: main ?? this.main,
      );
  CurrencyRow copyWithCompanion(CurrenciesCompanion data) {
    return CurrencyRow(
      code: data.code.present ? data.code.value : this.code,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      main: data.main.present ? data.main.value : this.main,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CurrencyRow(')
          ..write('code: $code, ')
          ..write('enabled: $enabled, ')
          ..write('main: $main')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, enabled, main);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CurrencyRow &&
          other.code == this.code &&
          other.enabled == this.enabled &&
          other.main == this.main);
}

class CurrenciesCompanion extends UpdateCompanion<CurrencyRow> {
  final Value<String> code;
  final Value<bool> enabled;
  final Value<bool> main;
  final Value<int> rowid;
  const CurrenciesCompanion({
    this.code = const Value.absent(),
    this.enabled = const Value.absent(),
    this.main = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrenciesCompanion.insert({
    required String code,
    this.enabled = const Value.absent(),
    this.main = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : code = Value(code);
  static Insertable<CurrencyRow> custom({
    Expression<String>? code,
    Expression<bool>? enabled,
    Expression<bool>? main,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (enabled != null) 'enabled': enabled,
      if (main != null) 'main': main,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrenciesCompanion copyWith({
    Value<String>? code,
    Value<bool>? enabled,
    Value<bool>? main,
    Value<int>? rowid,
  }) {
    return CurrenciesCompanion(
      code: code ?? this.code,
      enabled: enabled ?? this.enabled,
      main: main ?? this.main,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (main.present) {
      map['main'] = Variable<bool>(main.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrenciesCompanion(')
          ..write('code: $code, ')
          ..write('enabled: $enabled, ')
          ..write('main: $main, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TemplateItemsTable extends TemplateItems
    with TableInfo<$TemplateItemsTable, TemplateItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TemplateItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _variableMeta = const VerificationMeta(
    'variable',
  );
  @override
  late final GeneratedColumn<bool> variable = GeneratedColumn<bool>(
    'variable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("variable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    currency,
    kind,
    amount,
    expression,
    variable,
    position,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'template_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<TemplateItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    }
    if (data.containsKey('variable')) {
      context.handle(
        _variableMeta,
        variable.isAcceptableOrUnknown(data['variable']!, _variableMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TemplateItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TemplateItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      ),
      variable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}variable'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TemplateItemsTable createAlias(String alias) {
    return $TemplateItemsTable(attachedDatabase, alias);
  }
}

class TemplateItemRow extends DataClass implements Insertable<TemplateItemRow> {
  final String id;
  final String name;
  final String currency;
  final String kind;
  final double? amount;
  final String? expression;
  final bool variable;
  final int position;
  final String createdAt;
  const TemplateItemRow({
    required this.id,
    required this.name,
    required this.currency,
    required this.kind,
    this.amount,
    this.expression,
    required this.variable,
    required this.position,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || expression != null) {
      map['expression'] = Variable<String>(expression);
    }
    map['variable'] = Variable<bool>(variable);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  TemplateItemsCompanion toCompanion(bool nullToAbsent) {
    return TemplateItemsCompanion(
      id: Value(id),
      name: Value(name),
      currency: Value(currency),
      kind: Value(kind),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      expression: expression == null && nullToAbsent
          ? const Value.absent()
          : Value(expression),
      variable: Value(variable),
      position: Value(position),
      createdAt: Value(createdAt),
    );
  }

  factory TemplateItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TemplateItemRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      kind: serializer.fromJson<String>(json['kind']),
      amount: serializer.fromJson<double?>(json['amount']),
      expression: serializer.fromJson<String?>(json['expression']),
      variable: serializer.fromJson<bool>(json['variable']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'kind': serializer.toJson<String>(kind),
      'amount': serializer.toJson<double?>(amount),
      'expression': serializer.toJson<String?>(expression),
      'variable': serializer.toJson<bool>(variable),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  TemplateItemRow copyWith({
    String? id,
    String? name,
    String? currency,
    String? kind,
    Value<double?> amount = const Value.absent(),
    Value<String?> expression = const Value.absent(),
    bool? variable,
    int? position,
    String? createdAt,
  }) => TemplateItemRow(
    id: id ?? this.id,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    kind: kind ?? this.kind,
    amount: amount.present ? amount.value : this.amount,
    expression: expression.present ? expression.value : this.expression,
    variable: variable ?? this.variable,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
  );
  TemplateItemRow copyWithCompanion(TemplateItemsCompanion data) {
    return TemplateItemRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      kind: data.kind.present ? data.kind.value : this.kind,
      amount: data.amount.present ? data.amount.value : this.amount,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
      variable: data.variable.present ? data.variable.value : this.variable,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TemplateItemRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('variable: $variable, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    currency,
    kind,
    amount,
    expression,
    variable,
    position,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TemplateItemRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.kind == this.kind &&
          other.amount == this.amount &&
          other.expression == this.expression &&
          other.variable == this.variable &&
          other.position == this.position &&
          other.createdAt == this.createdAt);
}

class TemplateItemsCompanion extends UpdateCompanion<TemplateItemRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> currency;
  final Value<String> kind;
  final Value<double?> amount;
  final Value<String?> expression;
  final Value<bool> variable;
  final Value<int> position;
  final Value<String> createdAt;
  final Value<int> rowid;
  const TemplateItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.kind = const Value.absent(),
    this.amount = const Value.absent(),
    this.expression = const Value.absent(),
    this.variable = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TemplateItemsCompanion.insert({
    required String id,
    required String name,
    required String currency,
    required String kind,
    this.amount = const Value.absent(),
    this.expression = const Value.absent(),
    this.variable = const Value.absent(),
    required int position,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       currency = Value(currency),
       kind = Value(kind),
       position = Value(position),
       createdAt = Value(createdAt);
  static Insertable<TemplateItemRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<String>? kind,
    Expression<double>? amount,
    Expression<String>? expression,
    Expression<bool>? variable,
    Expression<int>? position,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (kind != null) 'kind': kind,
      if (amount != null) 'amount': amount,
      if (expression != null) 'expression': expression,
      if (variable != null) 'variable': variable,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TemplateItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? currency,
    Value<String>? kind,
    Value<double?>? amount,
    Value<String?>? expression,
    Value<bool>? variable,
    Value<int>? position,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return TemplateItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      expression: expression ?? this.expression,
      variable: variable ?? this.variable,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    if (variable.present) {
      map['variable'] = Variable<bool>(variable.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TemplateItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('variable: $variable, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthsTable extends Months with TableInfo<$MonthsTable, MonthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mainCurrencyMeta = const VerificationMeta(
    'mainCurrency',
  );
  @override
  late final GeneratedColumn<String> mainCurrency = GeneratedColumn<String>(
    'main_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lockedRatesMeta = const VerificationMeta(
    'lockedRates',
  );
  @override
  late final GeneratedColumn<String> lockedRates = GeneratedColumn<String>(
    'locked_rates',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _activeDayMeta = const VerificationMeta(
    'activeDay',
  );
  @override
  late final GeneratedColumn<int> activeDay = GeneratedColumn<int>(
    'active_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    year,
    month,
    mainCurrency,
    lockedRates,
    activeDay,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'months';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('main_currency')) {
      context.handle(
        _mainCurrencyMeta,
        mainCurrency.isAcceptableOrUnknown(
          data['main_currency']!,
          _mainCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mainCurrencyMeta);
    }
    if (data.containsKey('locked_rates')) {
      context.handle(
        _lockedRatesMeta,
        lockedRates.isAcceptableOrUnknown(
          data['locked_rates']!,
          _lockedRatesMeta,
        ),
      );
    }
    if (data.containsKey('active_day')) {
      context.handle(
        _activeDayMeta,
        activeDay.isAcceptableOrUnknown(data['active_day']!, _activeDayMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {year, month},
  ];
  @override
  MonthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      mainCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_currency'],
      )!,
      lockedRates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locked_rates'],
      )!,
      activeDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_day'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MonthsTable createAlias(String alias) {
    return $MonthsTable(attachedDatabase, alias);
  }
}

class MonthRow extends DataClass implements Insertable<MonthRow> {
  final String id;
  final int year;
  final int month;
  final String mainCurrency;

  /// JSON map of currency code to rate.
  final String lockedRates;
  final int? activeDay;
  final String? note;
  final String createdAt;
  const MonthRow({
    required this.id,
    required this.year,
    required this.month,
    required this.mainCurrency,
    required this.lockedRates,
    this.activeDay,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['main_currency'] = Variable<String>(mainCurrency);
    map['locked_rates'] = Variable<String>(lockedRates);
    if (!nullToAbsent || activeDay != null) {
      map['active_day'] = Variable<int>(activeDay);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  MonthsCompanion toCompanion(bool nullToAbsent) {
    return MonthsCompanion(
      id: Value(id),
      year: Value(year),
      month: Value(month),
      mainCurrency: Value(mainCurrency),
      lockedRates: Value(lockedRates),
      activeDay: activeDay == null && nullToAbsent
          ? const Value.absent()
          : Value(activeDay),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory MonthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthRow(
      id: serializer.fromJson<String>(json['id']),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      mainCurrency: serializer.fromJson<String>(json['mainCurrency']),
      lockedRates: serializer.fromJson<String>(json['lockedRates']),
      activeDay: serializer.fromJson<int?>(json['activeDay']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'mainCurrency': serializer.toJson<String>(mainCurrency),
      'lockedRates': serializer.toJson<String>(lockedRates),
      'activeDay': serializer.toJson<int?>(activeDay),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  MonthRow copyWith({
    String? id,
    int? year,
    int? month,
    String? mainCurrency,
    String? lockedRates,
    Value<int?> activeDay = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? createdAt,
  }) => MonthRow(
    id: id ?? this.id,
    year: year ?? this.year,
    month: month ?? this.month,
    mainCurrency: mainCurrency ?? this.mainCurrency,
    lockedRates: lockedRates ?? this.lockedRates,
    activeDay: activeDay.present ? activeDay.value : this.activeDay,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  MonthRow copyWithCompanion(MonthsCompanion data) {
    return MonthRow(
      id: data.id.present ? data.id.value : this.id,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      mainCurrency: data.mainCurrency.present
          ? data.mainCurrency.value
          : this.mainCurrency,
      lockedRates: data.lockedRates.present
          ? data.lockedRates.value
          : this.lockedRates,
      activeDay: data.activeDay.present ? data.activeDay.value : this.activeDay,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthRow(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('mainCurrency: $mainCurrency, ')
          ..write('lockedRates: $lockedRates, ')
          ..write('activeDay: $activeDay, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    year,
    month,
    mainCurrency,
    lockedRates,
    activeDay,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthRow &&
          other.id == this.id &&
          other.year == this.year &&
          other.month == this.month &&
          other.mainCurrency == this.mainCurrency &&
          other.lockedRates == this.lockedRates &&
          other.activeDay == this.activeDay &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class MonthsCompanion extends UpdateCompanion<MonthRow> {
  final Value<String> id;
  final Value<int> year;
  final Value<int> month;
  final Value<String> mainCurrency;
  final Value<String> lockedRates;
  final Value<int?> activeDay;
  final Value<String?> note;
  final Value<String> createdAt;
  final Value<int> rowid;
  const MonthsCompanion({
    this.id = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.mainCurrency = const Value.absent(),
    this.lockedRates = const Value.absent(),
    this.activeDay = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthsCompanion.insert({
    required String id,
    required int year,
    required int month,
    required String mainCurrency,
    this.lockedRates = const Value.absent(),
    this.activeDay = const Value.absent(),
    this.note = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       year = Value(year),
       month = Value(month),
       mainCurrency = Value(mainCurrency),
       createdAt = Value(createdAt);
  static Insertable<MonthRow> custom({
    Expression<String>? id,
    Expression<int>? year,
    Expression<int>? month,
    Expression<String>? mainCurrency,
    Expression<String>? lockedRates,
    Expression<int>? activeDay,
    Expression<String>? note,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (mainCurrency != null) 'main_currency': mainCurrency,
      if (lockedRates != null) 'locked_rates': lockedRates,
      if (activeDay != null) 'active_day': activeDay,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthsCompanion copyWith({
    Value<String>? id,
    Value<int>? year,
    Value<int>? month,
    Value<String>? mainCurrency,
    Value<String>? lockedRates,
    Value<int?>? activeDay,
    Value<String?>? note,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return MonthsCompanion(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      mainCurrency: mainCurrency ?? this.mainCurrency,
      lockedRates: lockedRates ?? this.lockedRates,
      activeDay: activeDay ?? this.activeDay,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (mainCurrency.present) {
      map['main_currency'] = Variable<String>(mainCurrency.value);
    }
    if (lockedRates.present) {
      map['locked_rates'] = Variable<String>(lockedRates.value);
    }
    if (activeDay.present) {
      map['active_day'] = Variable<int>(activeDay.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthsCompanion(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('mainCurrency: $mainCurrency, ')
          ..write('lockedRates: $lockedRates, ')
          ..write('activeDay: $activeDay, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MonthItemsTable extends MonthItems
    with TableInfo<$MonthItemsTable, MonthItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthIdMeta = const VerificationMeta(
    'monthId',
  );
  @override
  late final GeneratedColumn<String> monthId = GeneratedColumn<String>(
    'month_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES months (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _templateItemIdMeta = const VerificationMeta(
    'templateItemId',
  );
  @override
  late final GeneratedColumn<String> templateItemId = GeneratedColumn<String>(
    'template_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES template_items (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<bool> paid = GeneratedColumn<bool>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paid" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _needsReviewMeta = const VerificationMeta(
    'needsReview',
  );
  @override
  late final GeneratedColumn<bool> needsReview = GeneratedColumn<bool>(
    'needs_review',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_review" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    monthId,
    templateItemId,
    name,
    currency,
    kind,
    amount,
    expression,
    paid,
    needsReview,
    position,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'month_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('month_id')) {
      context.handle(
        _monthIdMeta,
        monthId.isAcceptableOrUnknown(data['month_id']!, _monthIdMeta),
      );
    } else if (isInserting) {
      context.missing(_monthIdMeta);
    }
    if (data.containsKey('template_item_id')) {
      context.handle(
        _templateItemIdMeta,
        templateItemId.isAcceptableOrUnknown(
          data['template_item_id']!,
          _templateItemIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    }
    if (data.containsKey('needs_review')) {
      context.handle(
        _needsReviewMeta,
        needsReview.isAcceptableOrUnknown(
          data['needs_review']!,
          _needsReviewMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MonthItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      monthId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_id'],
      )!,
      templateItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_item_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      ),
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      ),
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paid'],
      )!,
      needsReview: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_review'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MonthItemsTable createAlias(String alias) {
    return $MonthItemsTable(attachedDatabase, alias);
  }
}

class MonthItemRow extends DataClass implements Insertable<MonthItemRow> {
  final String id;
  final String monthId;
  final String? templateItemId;
  final String name;
  final String currency;
  final String kind;
  final double? amount;
  final String? expression;
  final bool paid;
  final bool needsReview;
  final int position;
  final String createdAt;
  const MonthItemRow({
    required this.id,
    required this.monthId,
    this.templateItemId,
    required this.name,
    required this.currency,
    required this.kind,
    this.amount,
    this.expression,
    required this.paid,
    required this.needsReview,
    required this.position,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['month_id'] = Variable<String>(monthId);
    if (!nullToAbsent || templateItemId != null) {
      map['template_item_id'] = Variable<String>(templateItemId);
    }
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    if (!nullToAbsent || expression != null) {
      map['expression'] = Variable<String>(expression);
    }
    map['paid'] = Variable<bool>(paid);
    map['needs_review'] = Variable<bool>(needsReview);
    map['position'] = Variable<int>(position);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  MonthItemsCompanion toCompanion(bool nullToAbsent) {
    return MonthItemsCompanion(
      id: Value(id),
      monthId: Value(monthId),
      templateItemId: templateItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateItemId),
      name: Value(name),
      currency: Value(currency),
      kind: Value(kind),
      amount: amount == null && nullToAbsent
          ? const Value.absent()
          : Value(amount),
      expression: expression == null && nullToAbsent
          ? const Value.absent()
          : Value(expression),
      paid: Value(paid),
      needsReview: Value(needsReview),
      position: Value(position),
      createdAt: Value(createdAt),
    );
  }

  factory MonthItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthItemRow(
      id: serializer.fromJson<String>(json['id']),
      monthId: serializer.fromJson<String>(json['monthId']),
      templateItemId: serializer.fromJson<String?>(json['templateItemId']),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      kind: serializer.fromJson<String>(json['kind']),
      amount: serializer.fromJson<double?>(json['amount']),
      expression: serializer.fromJson<String?>(json['expression']),
      paid: serializer.fromJson<bool>(json['paid']),
      needsReview: serializer.fromJson<bool>(json['needsReview']),
      position: serializer.fromJson<int>(json['position']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'monthId': serializer.toJson<String>(monthId),
      'templateItemId': serializer.toJson<String?>(templateItemId),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'kind': serializer.toJson<String>(kind),
      'amount': serializer.toJson<double?>(amount),
      'expression': serializer.toJson<String?>(expression),
      'paid': serializer.toJson<bool>(paid),
      'needsReview': serializer.toJson<bool>(needsReview),
      'position': serializer.toJson<int>(position),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  MonthItemRow copyWith({
    String? id,
    String? monthId,
    Value<String?> templateItemId = const Value.absent(),
    String? name,
    String? currency,
    String? kind,
    Value<double?> amount = const Value.absent(),
    Value<String?> expression = const Value.absent(),
    bool? paid,
    bool? needsReview,
    int? position,
    String? createdAt,
  }) => MonthItemRow(
    id: id ?? this.id,
    monthId: monthId ?? this.monthId,
    templateItemId: templateItemId.present
        ? templateItemId.value
        : this.templateItemId,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    kind: kind ?? this.kind,
    amount: amount.present ? amount.value : this.amount,
    expression: expression.present ? expression.value : this.expression,
    paid: paid ?? this.paid,
    needsReview: needsReview ?? this.needsReview,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
  );
  MonthItemRow copyWithCompanion(MonthItemsCompanion data) {
    return MonthItemRow(
      id: data.id.present ? data.id.value : this.id,
      monthId: data.monthId.present ? data.monthId.value : this.monthId,
      templateItemId: data.templateItemId.present
          ? data.templateItemId.value
          : this.templateItemId,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      kind: data.kind.present ? data.kind.value : this.kind,
      amount: data.amount.present ? data.amount.value : this.amount,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
      paid: data.paid.present ? data.paid.value : this.paid,
      needsReview: data.needsReview.present
          ? data.needsReview.value
          : this.needsReview,
      position: data.position.present ? data.position.value : this.position,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthItemRow(')
          ..write('id: $id, ')
          ..write('monthId: $monthId, ')
          ..write('templateItemId: $templateItemId, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('paid: $paid, ')
          ..write('needsReview: $needsReview, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    monthId,
    templateItemId,
    name,
    currency,
    kind,
    amount,
    expression,
    paid,
    needsReview,
    position,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthItemRow &&
          other.id == this.id &&
          other.monthId == this.monthId &&
          other.templateItemId == this.templateItemId &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.kind == this.kind &&
          other.amount == this.amount &&
          other.expression == this.expression &&
          other.paid == this.paid &&
          other.needsReview == this.needsReview &&
          other.position == this.position &&
          other.createdAt == this.createdAt);
}

class MonthItemsCompanion extends UpdateCompanion<MonthItemRow> {
  final Value<String> id;
  final Value<String> monthId;
  final Value<String?> templateItemId;
  final Value<String> name;
  final Value<String> currency;
  final Value<String> kind;
  final Value<double?> amount;
  final Value<String?> expression;
  final Value<bool> paid;
  final Value<bool> needsReview;
  final Value<int> position;
  final Value<String> createdAt;
  final Value<int> rowid;
  const MonthItemsCompanion({
    this.id = const Value.absent(),
    this.monthId = const Value.absent(),
    this.templateItemId = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.kind = const Value.absent(),
    this.amount = const Value.absent(),
    this.expression = const Value.absent(),
    this.paid = const Value.absent(),
    this.needsReview = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MonthItemsCompanion.insert({
    required String id,
    required String monthId,
    this.templateItemId = const Value.absent(),
    required String name,
    required String currency,
    required String kind,
    this.amount = const Value.absent(),
    this.expression = const Value.absent(),
    this.paid = const Value.absent(),
    this.needsReview = const Value.absent(),
    required int position,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       monthId = Value(monthId),
       name = Value(name),
       currency = Value(currency),
       kind = Value(kind),
       position = Value(position),
       createdAt = Value(createdAt);
  static Insertable<MonthItemRow> custom({
    Expression<String>? id,
    Expression<String>? monthId,
    Expression<String>? templateItemId,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<String>? kind,
    Expression<double>? amount,
    Expression<String>? expression,
    Expression<bool>? paid,
    Expression<bool>? needsReview,
    Expression<int>? position,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (monthId != null) 'month_id': monthId,
      if (templateItemId != null) 'template_item_id': templateItemId,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (kind != null) 'kind': kind,
      if (amount != null) 'amount': amount,
      if (expression != null) 'expression': expression,
      if (paid != null) 'paid': paid,
      if (needsReview != null) 'needs_review': needsReview,
      if (position != null) 'position': position,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MonthItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? monthId,
    Value<String?>? templateItemId,
    Value<String>? name,
    Value<String>? currency,
    Value<String>? kind,
    Value<double?>? amount,
    Value<String?>? expression,
    Value<bool>? paid,
    Value<bool>? needsReview,
    Value<int>? position,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return MonthItemsCompanion(
      id: id ?? this.id,
      monthId: monthId ?? this.monthId,
      templateItemId: templateItemId ?? this.templateItemId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      expression: expression ?? this.expression,
      paid: paid ?? this.paid,
      needsReview: needsReview ?? this.needsReview,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (monthId.present) {
      map['month_id'] = Variable<String>(monthId.value);
    }
    if (templateItemId.present) {
      map['template_item_id'] = Variable<String>(templateItemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    if (paid.present) {
      map['paid'] = Variable<bool>(paid.value);
    }
    if (needsReview.present) {
      map['needs_review'] = Variable<bool>(needsReview.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthItemsCompanion(')
          ..write('id: $id, ')
          ..write('monthId: $monthId, ')
          ..write('templateItemId: $templateItemId, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('kind: $kind, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('paid: $paid, ')
          ..write('needsReview: $needsReview, ')
          ..write('position: $position, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailySpendsTable extends DailySpends
    with TableInfo<$DailySpendsTable, DailySpendRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySpendsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthIdMeta = const VerificationMeta(
    'monthId',
  );
  @override
  late final GeneratedColumn<String> monthId = GeneratedColumn<String>(
    'month_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES months (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expressionMeta = const VerificationMeta(
    'expression',
  );
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
    'expression',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    monthId,
    day,
    currency,
    amount,
    expression,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_spends';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySpendRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('month_id')) {
      context.handle(
        _monthIdMeta,
        monthId.isAcceptableOrUnknown(data['month_id']!, _monthIdMeta),
      );
    } else if (isInserting) {
      context.missing(_monthIdMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('expression')) {
      context.handle(
        _expressionMeta,
        expression.isAcceptableOrUnknown(data['expression']!, _expressionMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailySpendRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySpendRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      monthId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_id'],
      )!,
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      expression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expression'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DailySpendsTable createAlias(String alias) {
    return $DailySpendsTable(attachedDatabase, alias);
  }
}

class DailySpendRow extends DataClass implements Insertable<DailySpendRow> {
  final String id;
  final String monthId;
  final int day;
  final String currency;
  final double amount;
  final String? expression;
  final String? note;
  final String createdAt;
  const DailySpendRow({
    required this.id,
    required this.monthId,
    required this.day,
    required this.currency,
    required this.amount,
    this.expression,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['month_id'] = Variable<String>(monthId);
    map['day'] = Variable<int>(day);
    map['currency'] = Variable<String>(currency);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || expression != null) {
      map['expression'] = Variable<String>(expression);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  DailySpendsCompanion toCompanion(bool nullToAbsent) {
    return DailySpendsCompanion(
      id: Value(id),
      monthId: Value(monthId),
      day: Value(day),
      currency: Value(currency),
      amount: Value(amount),
      expression: expression == null && nullToAbsent
          ? const Value.absent()
          : Value(expression),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory DailySpendRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySpendRow(
      id: serializer.fromJson<String>(json['id']),
      monthId: serializer.fromJson<String>(json['monthId']),
      day: serializer.fromJson<int>(json['day']),
      currency: serializer.fromJson<String>(json['currency']),
      amount: serializer.fromJson<double>(json['amount']),
      expression: serializer.fromJson<String?>(json['expression']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'monthId': serializer.toJson<String>(monthId),
      'day': serializer.toJson<int>(day),
      'currency': serializer.toJson<String>(currency),
      'amount': serializer.toJson<double>(amount),
      'expression': serializer.toJson<String?>(expression),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  DailySpendRow copyWith({
    String? id,
    String? monthId,
    int? day,
    String? currency,
    double? amount,
    Value<String?> expression = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? createdAt,
  }) => DailySpendRow(
    id: id ?? this.id,
    monthId: monthId ?? this.monthId,
    day: day ?? this.day,
    currency: currency ?? this.currency,
    amount: amount ?? this.amount,
    expression: expression.present ? expression.value : this.expression,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  DailySpendRow copyWithCompanion(DailySpendsCompanion data) {
    return DailySpendRow(
      id: data.id.present ? data.id.value : this.id,
      monthId: data.monthId.present ? data.monthId.value : this.monthId,
      day: data.day.present ? data.day.value : this.day,
      currency: data.currency.present ? data.currency.value : this.currency,
      amount: data.amount.present ? data.amount.value : this.amount,
      expression: data.expression.present
          ? data.expression.value
          : this.expression,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySpendRow(')
          ..write('id: $id, ')
          ..write('monthId: $monthId, ')
          ..write('day: $day, ')
          ..write('currency: $currency, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    monthId,
    day,
    currency,
    amount,
    expression,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySpendRow &&
          other.id == this.id &&
          other.monthId == this.monthId &&
          other.day == this.day &&
          other.currency == this.currency &&
          other.amount == this.amount &&
          other.expression == this.expression &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class DailySpendsCompanion extends UpdateCompanion<DailySpendRow> {
  final Value<String> id;
  final Value<String> monthId;
  final Value<int> day;
  final Value<String> currency;
  final Value<double> amount;
  final Value<String?> expression;
  final Value<String?> note;
  final Value<String> createdAt;
  final Value<int> rowid;
  const DailySpendsCompanion({
    this.id = const Value.absent(),
    this.monthId = const Value.absent(),
    this.day = const Value.absent(),
    this.currency = const Value.absent(),
    this.amount = const Value.absent(),
    this.expression = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailySpendsCompanion.insert({
    required String id,
    required String monthId,
    required int day,
    required String currency,
    required double amount,
    this.expression = const Value.absent(),
    this.note = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       monthId = Value(monthId),
       day = Value(day),
       currency = Value(currency),
       amount = Value(amount),
       createdAt = Value(createdAt);
  static Insertable<DailySpendRow> custom({
    Expression<String>? id,
    Expression<String>? monthId,
    Expression<int>? day,
    Expression<String>? currency,
    Expression<double>? amount,
    Expression<String>? expression,
    Expression<String>? note,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (monthId != null) 'month_id': monthId,
      if (day != null) 'day': day,
      if (currency != null) 'currency': currency,
      if (amount != null) 'amount': amount,
      if (expression != null) 'expression': expression,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailySpendsCompanion copyWith({
    Value<String>? id,
    Value<String>? monthId,
    Value<int>? day,
    Value<String>? currency,
    Value<double>? amount,
    Value<String?>? expression,
    Value<String?>? note,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return DailySpendsCompanion(
      id: id ?? this.id,
      monthId: monthId ?? this.monthId,
      day: day ?? this.day,
      currency: currency ?? this.currency,
      amount: amount ?? this.amount,
      expression: expression ?? this.expression,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (monthId.present) {
      map['month_id'] = Variable<String>(monthId.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySpendsCompanion(')
          ..write('id: $id, ')
          ..write('monthId: $monthId, ')
          ..write('day: $day, ')
          ..write('currency: $currency, ')
          ..write('amount: $amount, ')
          ..write('expression: $expression, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredRatesTable extends StoredRates
    with TableInfo<$StoredRatesTable, StoredRate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredRatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _baseMeta = const VerificationMeta('base');
  @override
  late final GeneratedColumn<String> base = GeneratedColumn<String>(
    'base',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratesMeta = const VerificationMeta('rates');
  @override
  late final GeneratedColumn<String> rates = GeneratedColumn<String>(
    'rates',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<String> fetchedAt = GeneratedColumn<String>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [base, rates, source, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_rates';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredRate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('base')) {
      context.handle(
        _baseMeta,
        base.isAcceptableOrUnknown(data['base']!, _baseMeta),
      );
    } else if (isInserting) {
      context.missing(_baseMeta);
    }
    if (data.containsKey('rates')) {
      context.handle(
        _ratesMeta,
        rates.isAcceptableOrUnknown(data['rates']!, _ratesMeta),
      );
    } else if (isInserting) {
      context.missing(_ratesMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {base};
  @override
  StoredRate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredRate(
      base: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base'],
      )!,
      rates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rates'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $StoredRatesTable createAlias(String alias) {
    return $StoredRatesTable(attachedDatabase, alias);
  }
}

class StoredRate extends DataClass implements Insertable<StoredRate> {
  final String base;

  /// JSON map of currency code to rate.
  final String rates;
  final String source;
  final String fetchedAt;
  const StoredRate({
    required this.base,
    required this.rates,
    required this.source,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['base'] = Variable<String>(base);
    map['rates'] = Variable<String>(rates);
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<String>(fetchedAt);
    return map;
  }

  StoredRatesCompanion toCompanion(bool nullToAbsent) {
    return StoredRatesCompanion(
      base: Value(base),
      rates: Value(rates),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory StoredRate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredRate(
      base: serializer.fromJson<String>(json['base']),
      rates: serializer.fromJson<String>(json['rates']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<String>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'base': serializer.toJson<String>(base),
      'rates': serializer.toJson<String>(rates),
      'source': serializer.toJson<String>(source),
      'fetchedAt': serializer.toJson<String>(fetchedAt),
    };
  }

  StoredRate copyWith({
    String? base,
    String? rates,
    String? source,
    String? fetchedAt,
  }) => StoredRate(
    base: base ?? this.base,
    rates: rates ?? this.rates,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  StoredRate copyWithCompanion(StoredRatesCompanion data) {
    return StoredRate(
      base: data.base.present ? data.base.value : this.base,
      rates: data.rates.present ? data.rates.value : this.rates,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredRate(')
          ..write('base: $base, ')
          ..write('rates: $rates, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(base, rates, source, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredRate &&
          other.base == this.base &&
          other.rates == this.rates &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt);
}

class StoredRatesCompanion extends UpdateCompanion<StoredRate> {
  final Value<String> base;
  final Value<String> rates;
  final Value<String> source;
  final Value<String> fetchedAt;
  final Value<int> rowid;
  const StoredRatesCompanion({
    this.base = const Value.absent(),
    this.rates = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredRatesCompanion.insert({
    required String base,
    required String rates,
    required String source,
    required String fetchedAt,
    this.rowid = const Value.absent(),
  }) : base = Value(base),
       rates = Value(rates),
       source = Value(source),
       fetchedAt = Value(fetchedAt);
  static Insertable<StoredRate> custom({
    Expression<String>? base,
    Expression<String>? rates,
    Expression<String>? source,
    Expression<String>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (base != null) 'base': base,
      if (rates != null) 'rates': rates,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredRatesCompanion copyWith({
    Value<String>? base,
    Value<String>? rates,
    Value<String>? source,
    Value<String>? fetchedAt,
    Value<int>? rowid,
  }) {
    return StoredRatesCompanion(
      base: base ?? this.base,
      rates: rates ?? this.rates,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (base.present) {
      map['base'] = Variable<String>(base.value);
    }
    if (rates.present) {
      map['rates'] = Variable<String>(rates.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<String>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredRatesCompanion(')
          ..write('base: $base, ')
          ..write('rates: $rates, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $CurrenciesTable currencies = $CurrenciesTable(this);
  late final $TemplateItemsTable templateItems = $TemplateItemsTable(this);
  late final $MonthsTable months = $MonthsTable(this);
  late final $MonthItemsTable monthItems = $MonthItemsTable(this);
  late final $DailySpendsTable dailySpends = $DailySpendsTable(this);
  late final $StoredRatesTable storedRates = $StoredRatesTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    currencies,
    templateItems,
    months,
    monthItems,
    dailySpends,
    storedRates,
    meta,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'months',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('month_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'template_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('month_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'months',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('daily_spends', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CurrenciesTableCreateCompanionBuilder = CurrenciesCompanion Function({
  required String code,
  Value<bool> enabled,
  Value<bool> main,
  Value<int> rowid,
});
typedef $$CurrenciesTableUpdateCompanionBuilder = CurrenciesCompanion Function({
  Value<String> code,
  Value<bool> enabled,
  Value<bool> main,
  Value<int> rowid,
});

class $$CurrenciesTableFilterComposer
    extends Composer<_$LocalDatabase, $CurrenciesTable> {
  $$CurrenciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get main => $composableBuilder(
    column: $table.main,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurrenciesTableOrderingComposer
    extends Composer<_$LocalDatabase, $CurrenciesTable> {
  $$CurrenciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get main => $composableBuilder(
    column: $table.main,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurrenciesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $CurrenciesTable> {
  $$CurrenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get main =>
      $composableBuilder(column: $table.main, builder: (column) => column);
}

class $$CurrenciesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $CurrenciesTable,
          CurrencyRow,
          $$CurrenciesTableFilterComposer,
          $$CurrenciesTableOrderingComposer,
          $$CurrenciesTableAnnotationComposer,
          $$CurrenciesTableCreateCompanionBuilder,
          $$CurrenciesTableUpdateCompanionBuilder,
          (
            CurrencyRow,
            BaseReferences<_$LocalDatabase, $CurrenciesTable, CurrencyRow>,
          ),
          CurrencyRow,
          PrefetchHooks Function()
        > {
  $$CurrenciesTableTableManager(_$LocalDatabase db, $CurrenciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrenciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrenciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrenciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> main = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion(
                code: code,
                enabled: enabled,
                main: main,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                Value<bool> enabled = const Value.absent(),
                Value<bool> main = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion.insert(
                code: code,
                enabled: enabled,
                main: main,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CurrenciesTable, CurrencyRow>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $CurrenciesTable,
                    CurrencyRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurrenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $CurrenciesTable,
      CurrencyRow,
      $$CurrenciesTableFilterComposer,
      $$CurrenciesTableOrderingComposer,
      $$CurrenciesTableAnnotationComposer,
      $$CurrenciesTableCreateCompanionBuilder,
      $$CurrenciesTableUpdateCompanionBuilder,
      (
        CurrencyRow,
        BaseReferences<_$LocalDatabase, $CurrenciesTable, CurrencyRow>,
      ),
      CurrencyRow,
      PrefetchHooks Function()
    >;
typedef $$TemplateItemsTableCreateCompanionBuilder =
    TemplateItemsCompanion Function({
      required String id,
      required String name,
      required String currency,
      required String kind,
      Value<double?> amount,
      Value<String?> expression,
      Value<bool> variable,
      required int position,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$TemplateItemsTableUpdateCompanionBuilder =
    TemplateItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> currency,
      Value<String> kind,
      Value<double?> amount,
      Value<String?> expression,
      Value<bool> variable,
      Value<int> position,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$TemplateItemsTableReferences
    extends
        BaseReferences<_$LocalDatabase, $TemplateItemsTable, TemplateItemRow> {
  $$TemplateItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MonthItemsTable, List<MonthItemRow>>
  _monthItemsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.monthItems,
    aliasName: 'template_items__id__month_items__template_item_id',
  );

  $$MonthItemsTableProcessedTableManager get monthItemsRefs {
    final manager = $$MonthItemsTableTableManager(
      $_db,
      $_db.monthItems,
    ).filter((f) => f.templateItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_monthItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TemplateItemsTableFilterComposer
    extends Composer<_$LocalDatabase, $TemplateItemsTable> {
  $$TemplateItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> monthItemsRefs(
    Expression<bool> Function($$MonthItemsTableFilterComposer f) f,
  ) {
    final $$MonthItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthItems,
      getReferencedColumn: (t) => t.templateItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthItemsTableFilterComposer(
            $db: $db,
            $table: $db.monthItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplateItemsTableOrderingComposer
    extends Composer<_$LocalDatabase, $TemplateItemsTable> {
  $$TemplateItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get variable => $composableBuilder(
    column: $table.variable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TemplateItemsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $TemplateItemsTable> {
  $$TemplateItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get variable =>
      $composableBuilder(column: $table.variable, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> monthItemsRefs<T extends Object>(
    Expression<T> Function($$MonthItemsTableAnnotationComposer a) f,
  ) {
    final $$MonthItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthItems,
      getReferencedColumn: (t) => t.templateItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.monthItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TemplateItemsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $TemplateItemsTable,
          TemplateItemRow,
          $$TemplateItemsTableFilterComposer,
          $$TemplateItemsTableOrderingComposer,
          $$TemplateItemsTableAnnotationComposer,
          $$TemplateItemsTableCreateCompanionBuilder,
          $$TemplateItemsTableUpdateCompanionBuilder,
          (TemplateItemRow, $$TemplateItemsTableReferences),
          TemplateItemRow,
          PrefetchHooks Function({bool monthItemsRefs})
        > {
  $$TemplateItemsTableTableManager(
    _$LocalDatabase db,
    $TemplateItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TemplateItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TemplateItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TemplateItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> expression = const Value.absent(),
                Value<bool> variable = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TemplateItemsCompanion(
                id: id,
                name: name,
                currency: currency,
                kind: kind,
                amount: amount,
                expression: expression,
                variable: variable,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String currency,
                required String kind,
                Value<double?> amount = const Value.absent(),
                Value<String?> expression = const Value.absent(),
                Value<bool> variable = const Value.absent(),
                required int position,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TemplateItemsCompanion.insert(
                id: id,
                name: name,
                currency: currency,
                kind: kind,
                amount: amount,
                expression: expression,
                variable: variable,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TemplateItemsTable, TemplateItemRow>(table),
                  $$TemplateItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({monthItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (monthItemsRefs) db.monthItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (monthItemsRefs)
                    await $_getPrefetchedDataByColumns<
                      TemplateItemRow,
                      $TemplateItemsTable,
                      MonthItemRow,
                      $MonthItemsTable
                    >(
                      currentTable: table,
                      referencedTable: $$TemplateItemsTableReferences
                          ._monthItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TemplateItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).monthItemsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'template_item_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TemplateItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $TemplateItemsTable,
      TemplateItemRow,
      $$TemplateItemsTableFilterComposer,
      $$TemplateItemsTableOrderingComposer,
      $$TemplateItemsTableAnnotationComposer,
      $$TemplateItemsTableCreateCompanionBuilder,
      $$TemplateItemsTableUpdateCompanionBuilder,
      (TemplateItemRow, $$TemplateItemsTableReferences),
      TemplateItemRow,
      PrefetchHooks Function({bool monthItemsRefs})
    >;
typedef $$MonthsTableCreateCompanionBuilder = MonthsCompanion Function({
  required String id,
  required int year,
  required int month,
  required String mainCurrency,
  Value<String> lockedRates,
  Value<int?> activeDay,
  Value<String?> note,
  required String createdAt,
  Value<int> rowid,
});
typedef $$MonthsTableUpdateCompanionBuilder = MonthsCompanion Function({
  Value<String> id,
  Value<int> year,
  Value<int> month,
  Value<String> mainCurrency,
  Value<String> lockedRates,
  Value<int?> activeDay,
  Value<String?> note,
  Value<String> createdAt,
  Value<int> rowid,
});

final class $$MonthsTableReferences
    extends BaseReferences<_$LocalDatabase, $MonthsTable, MonthRow> {
  $$MonthsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MonthItemsTable, List<MonthItemRow>>
  _monthItemsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.monthItems,
    aliasName: 'months__id__month_items__month_id',
  );

  $$MonthItemsTableProcessedTableManager get monthItemsRefs {
    final manager = $$MonthItemsTableTableManager(
      $_db,
      $_db.monthItems,
    ).filter((f) => f.monthId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_monthItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DailySpendsTable, List<DailySpendRow>>
  _dailySpendsRefsTable(_$LocalDatabase db) => MultiTypedResultKey.fromTable(
    db.dailySpends,
    aliasName: 'months__id__daily_spends__month_id',
  );

  $$DailySpendsTableProcessedTableManager get dailySpendsRefs {
    final manager = $$DailySpendsTableTableManager(
      $_db,
      $_db.dailySpends,
    ).filter((f) => f.monthId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dailySpendsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MonthsTableFilterComposer
    extends Composer<_$LocalDatabase, $MonthsTable> {
  $$MonthsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mainCurrency => $composableBuilder(
    column: $table.mainCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lockedRates => $composableBuilder(
    column: $table.lockedRates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeDay => $composableBuilder(
    column: $table.activeDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> monthItemsRefs(
    Expression<bool> Function($$MonthItemsTableFilterComposer f) f,
  ) {
    final $$MonthItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthItems,
      getReferencedColumn: (t) => t.monthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthItemsTableFilterComposer(
            $db: $db,
            $table: $db.monthItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dailySpendsRefs(
    Expression<bool> Function($$DailySpendsTableFilterComposer f) f,
  ) {
    final $$DailySpendsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailySpends,
      getReferencedColumn: (t) => t.monthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySpendsTableFilterComposer(
            $db: $db,
            $table: $db.dailySpends,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MonthsTableOrderingComposer
    extends Composer<_$LocalDatabase, $MonthsTable> {
  $$MonthsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mainCurrency => $composableBuilder(
    column: $table.mainCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lockedRates => $composableBuilder(
    column: $table.lockedRates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeDay => $composableBuilder(
    column: $table.activeDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MonthsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MonthsTable> {
  $$MonthsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get mainCurrency => $composableBuilder(
    column: $table.mainCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lockedRates => $composableBuilder(
    column: $table.lockedRates,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeDay =>
      $composableBuilder(column: $table.activeDay, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> monthItemsRefs<T extends Object>(
    Expression<T> Function($$MonthItemsTableAnnotationComposer a) f,
  ) {
    final $$MonthItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.monthItems,
      getReferencedColumn: (t) => t.monthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.monthItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dailySpendsRefs<T extends Object>(
    Expression<T> Function($$DailySpendsTableAnnotationComposer a) f,
  ) {
    final $$DailySpendsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailySpends,
      getReferencedColumn: (t) => t.monthId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailySpendsTableAnnotationComposer(
            $db: $db,
            $table: $db.dailySpends,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MonthsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MonthsTable,
          MonthRow,
          $$MonthsTableFilterComposer,
          $$MonthsTableOrderingComposer,
          $$MonthsTableAnnotationComposer,
          $$MonthsTableCreateCompanionBuilder,
          $$MonthsTableUpdateCompanionBuilder,
          (MonthRow, $$MonthsTableReferences),
          MonthRow,
          PrefetchHooks Function({bool monthItemsRefs, bool dailySpendsRefs})
        > {
  $$MonthsTableTableManager(_$LocalDatabase db, $MonthsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<String> mainCurrency = const Value.absent(),
                Value<String> lockedRates = const Value.absent(),
                Value<int?> activeDay = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthsCompanion(
                id: id,
                year: year,
                month: month,
                mainCurrency: mainCurrency,
                lockedRates: lockedRates,
                activeDay: activeDay,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int year,
                required int month,
                required String mainCurrency,
                Value<String> lockedRates = const Value.absent(),
                Value<int?> activeDay = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MonthsCompanion.insert(
                id: id,
                year: year,
                month: month,
                mainCurrency: mainCurrency,
                lockedRates: lockedRates,
                activeDay: activeDay,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonthsTable, MonthRow>(table),
                  $$MonthsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({monthItemsRefs = false, dailySpendsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (monthItemsRefs) db.monthItems,
                    if (dailySpendsRefs) db.dailySpends,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (monthItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          MonthRow,
                          $MonthsTable,
                          MonthItemRow,
                          $MonthItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MonthsTableReferences
                              ._monthItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MonthsTableReferences(
                                db,
                                table,
                                p0,
                              ).monthItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'month_id',
                          typedResults: items,
                        ),
                      if (dailySpendsRefs)
                        await $_getPrefetchedDataByColumns<
                          MonthRow,
                          $MonthsTable,
                          DailySpendRow,
                          $DailySpendsTable
                        >(
                          currentTable: table,
                          referencedTable: $$MonthsTableReferences
                              ._dailySpendsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MonthsTableReferences(
                                db,
                                table,
                                p0,
                              ).dailySpendsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'month_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MonthsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MonthsTable,
      MonthRow,
      $$MonthsTableFilterComposer,
      $$MonthsTableOrderingComposer,
      $$MonthsTableAnnotationComposer,
      $$MonthsTableCreateCompanionBuilder,
      $$MonthsTableUpdateCompanionBuilder,
      (MonthRow, $$MonthsTableReferences),
      MonthRow,
      PrefetchHooks Function({bool monthItemsRefs, bool dailySpendsRefs})
    >;
typedef $$MonthItemsTableCreateCompanionBuilder = MonthItemsCompanion Function({
  required String id,
  required String monthId,
  Value<String?> templateItemId,
  required String name,
  required String currency,
  required String kind,
  Value<double?> amount,
  Value<String?> expression,
  Value<bool> paid,
  Value<bool> needsReview,
  required int position,
  required String createdAt,
  Value<int> rowid,
});
typedef $$MonthItemsTableUpdateCompanionBuilder = MonthItemsCompanion Function({
  Value<String> id,
  Value<String> monthId,
  Value<String?> templateItemId,
  Value<String> name,
  Value<String> currency,
  Value<String> kind,
  Value<double?> amount,
  Value<String?> expression,
  Value<bool> paid,
  Value<bool> needsReview,
  Value<int> position,
  Value<String> createdAt,
  Value<int> rowid,
});

final class $$MonthItemsTableReferences
    extends BaseReferences<_$LocalDatabase, $MonthItemsTable, MonthItemRow> {
  $$MonthItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MonthsTable _monthIdTable(_$LocalDatabase db) =>
      db.months.createAlias('month_items__month_id__months__id');

  $$MonthsTableProcessedTableManager get monthId {
    final $_column = $_itemColumn<String>('month_id')!;

    final manager = $$MonthsTableTableManager(
      $_db,
      $_db.months,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_monthIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TemplateItemsTable _templateItemIdTable(_$LocalDatabase db) => db
      .templateItems
      .createAlias('month_items__template_item_id__template_items__id');

  $$TemplateItemsTableProcessedTableManager? get templateItemId {
    final $_column = $_itemColumn<String>('template_item_id');
    if ($_column == null) return null;
    final manager = $$TemplateItemsTableTableManager(
      $_db,
      $_db.templateItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MonthItemsTableFilterComposer
    extends Composer<_$LocalDatabase, $MonthItemsTable> {
  $$MonthItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MonthsTableFilterComposer get monthId {
    final $$MonthsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableFilterComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TemplateItemsTableFilterComposer get templateItemId {
    final $$TemplateItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateItemId,
      referencedTable: $db.templateItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplateItemsTableFilterComposer(
            $db: $db,
            $table: $db.templateItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthItemsTableOrderingComposer
    extends Composer<_$LocalDatabase, $MonthItemsTable> {
  $$MonthItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MonthsTableOrderingComposer get monthId {
    final $$MonthsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableOrderingComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TemplateItemsTableOrderingComposer get templateItemId {
    final $$TemplateItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateItemId,
      referencedTable: $db.templateItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplateItemsTableOrderingComposer(
            $db: $db,
            $table: $db.templateItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthItemsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MonthItemsTable> {
  $$MonthItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<bool> get needsReview => $composableBuilder(
    column: $table.needsReview,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MonthsTableAnnotationComposer get monthId {
    final $$MonthsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableAnnotationComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TemplateItemsTableAnnotationComposer get templateItemId {
    final $$TemplateItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateItemId,
      referencedTable: $db.templateItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TemplateItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.templateItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthItemsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MonthItemsTable,
          MonthItemRow,
          $$MonthItemsTableFilterComposer,
          $$MonthItemsTableOrderingComposer,
          $$MonthItemsTableAnnotationComposer,
          $$MonthItemsTableCreateCompanionBuilder,
          $$MonthItemsTableUpdateCompanionBuilder,
          (MonthItemRow, $$MonthItemsTableReferences),
          MonthItemRow,
          PrefetchHooks Function({bool monthId, bool templateItemId})
        > {
  $$MonthItemsTableTableManager(_$LocalDatabase db, $MonthItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MonthItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MonthItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> monthId = const Value.absent(),
                Value<String?> templateItemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String?> expression = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MonthItemsCompanion(
                id: id,
                monthId: monthId,
                templateItemId: templateItemId,
                name: name,
                currency: currency,
                kind: kind,
                amount: amount,
                expression: expression,
                paid: paid,
                needsReview: needsReview,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String monthId,
                Value<String?> templateItemId = const Value.absent(),
                required String name,
                required String currency,
                required String kind,
                Value<double?> amount = const Value.absent(),
                Value<String?> expression = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<bool> needsReview = const Value.absent(),
                required int position,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MonthItemsCompanion.insert(
                id: id,
                monthId: monthId,
                templateItemId: templateItemId,
                name: name,
                currency: currency,
                kind: kind,
                amount: amount,
                expression: expression,
                paid: paid,
                needsReview: needsReview,
                position: position,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MonthItemsTable, MonthItemRow>(table),
                  $$MonthItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({monthId = false, templateItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (monthId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.monthId,
                        referencedTable: $$MonthItemsTableReferences
                            ._monthIdTable(db),
                        referencedColumn: $$MonthItemsTableReferences
                            ._monthIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (templateItemId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.templateItemId,
                        referencedTable: $$MonthItemsTableReferences
                            ._templateItemIdTable(db),
                        referencedColumn: $$MonthItemsTableReferences
                            ._templateItemIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MonthItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MonthItemsTable,
      MonthItemRow,
      $$MonthItemsTableFilterComposer,
      $$MonthItemsTableOrderingComposer,
      $$MonthItemsTableAnnotationComposer,
      $$MonthItemsTableCreateCompanionBuilder,
      $$MonthItemsTableUpdateCompanionBuilder,
      (MonthItemRow, $$MonthItemsTableReferences),
      MonthItemRow,
      PrefetchHooks Function({bool monthId, bool templateItemId})
    >;
typedef $$DailySpendsTableCreateCompanionBuilder =
    DailySpendsCompanion Function({
      required String id,
      required String monthId,
      required int day,
      required String currency,
      required double amount,
      Value<String?> expression,
      Value<String?> note,
      required String createdAt,
      Value<int> rowid,
    });
typedef $$DailySpendsTableUpdateCompanionBuilder =
    DailySpendsCompanion Function({
      Value<String> id,
      Value<String> monthId,
      Value<int> day,
      Value<String> currency,
      Value<double> amount,
      Value<String?> expression,
      Value<String?> note,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $$DailySpendsTableReferences
    extends BaseReferences<_$LocalDatabase, $DailySpendsTable, DailySpendRow> {
  $$DailySpendsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MonthsTable _monthIdTable(_$LocalDatabase db) =>
      db.months.createAlias('daily_spends__month_id__months__id');

  $$MonthsTableProcessedTableManager get monthId {
    final $_column = $_itemColumn<String>('month_id')!;

    final manager = $$MonthsTableTableManager(
      $_db,
      $_db.months,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_monthIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailySpendsTableFilterComposer
    extends Composer<_$LocalDatabase, $DailySpendsTable> {
  $$DailySpendsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MonthsTableFilterComposer get monthId {
    final $$MonthsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableFilterComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySpendsTableOrderingComposer
    extends Composer<_$LocalDatabase, $DailySpendsTable> {
  $$DailySpendsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MonthsTableOrderingComposer get monthId {
    final $$MonthsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableOrderingComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySpendsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $DailySpendsTable> {
  $$DailySpendsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get expression => $composableBuilder(
    column: $table.expression,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MonthsTableAnnotationComposer get monthId {
    final $$MonthsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.monthId,
      referencedTable: $db.months,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MonthsTableAnnotationComposer(
            $db: $db,
            $table: $db.months,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailySpendsTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $DailySpendsTable,
          DailySpendRow,
          $$DailySpendsTableFilterComposer,
          $$DailySpendsTableOrderingComposer,
          $$DailySpendsTableAnnotationComposer,
          $$DailySpendsTableCreateCompanionBuilder,
          $$DailySpendsTableUpdateCompanionBuilder,
          (DailySpendRow, $$DailySpendsTableReferences),
          DailySpendRow,
          PrefetchHooks Function({bool monthId})
        > {
  $$DailySpendsTableTableManager(_$LocalDatabase db, $DailySpendsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySpendsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySpendsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySpendsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> monthId = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String?> expression = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailySpendsCompanion(
                id: id,
                monthId: monthId,
                day: day,
                currency: currency,
                amount: amount,
                expression: expression,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String monthId,
                required int day,
                required String currency,
                required double amount,
                Value<String?> expression = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DailySpendsCompanion.insert(
                id: id,
                monthId: monthId,
                day: day,
                currency: currency,
                amount: amount,
                expression: expression,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailySpendsTable, DailySpendRow>(table),
                  $$DailySpendsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({monthId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (monthId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.monthId,
                        referencedTable: $$DailySpendsTableReferences
                            ._monthIdTable(db),
                        referencedColumn: $$DailySpendsTableReferences
                            ._monthIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DailySpendsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $DailySpendsTable,
      DailySpendRow,
      $$DailySpendsTableFilterComposer,
      $$DailySpendsTableOrderingComposer,
      $$DailySpendsTableAnnotationComposer,
      $$DailySpendsTableCreateCompanionBuilder,
      $$DailySpendsTableUpdateCompanionBuilder,
      (DailySpendRow, $$DailySpendsTableReferences),
      DailySpendRow,
      PrefetchHooks Function({bool monthId})
    >;
typedef $$StoredRatesTableCreateCompanionBuilder =
    StoredRatesCompanion Function({
      required String base,
      required String rates,
      required String source,
      required String fetchedAt,
      Value<int> rowid,
    });
typedef $$StoredRatesTableUpdateCompanionBuilder =
    StoredRatesCompanion Function({
      Value<String> base,
      Value<String> rates,
      Value<String> source,
      Value<String> fetchedAt,
      Value<int> rowid,
    });

class $$StoredRatesTableFilterComposer
    extends Composer<_$LocalDatabase, $StoredRatesTable> {
  $$StoredRatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get base => $composableBuilder(
    column: $table.base,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rates => $composableBuilder(
    column: $table.rates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredRatesTableOrderingComposer
    extends Composer<_$LocalDatabase, $StoredRatesTable> {
  $$StoredRatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get base => $composableBuilder(
    column: $table.base,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rates => $composableBuilder(
    column: $table.rates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredRatesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $StoredRatesTable> {
  $$StoredRatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get base =>
      $composableBuilder(column: $table.base, builder: (column) => column);

  GeneratedColumn<String> get rates =>
      $composableBuilder(column: $table.rates, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$StoredRatesTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $StoredRatesTable,
          StoredRate,
          $$StoredRatesTableFilterComposer,
          $$StoredRatesTableOrderingComposer,
          $$StoredRatesTableAnnotationComposer,
          $$StoredRatesTableCreateCompanionBuilder,
          $$StoredRatesTableUpdateCompanionBuilder,
          (
            StoredRate,
            BaseReferences<_$LocalDatabase, $StoredRatesTable, StoredRate>,
          ),
          StoredRate,
          PrefetchHooks Function()
        > {
  $$StoredRatesTableTableManager(_$LocalDatabase db, $StoredRatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredRatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoredRatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoredRatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> base = const Value.absent(),
                Value<String> rates = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredRatesCompanion(
                base: base,
                rates: rates,
                source: source,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String base,
                required String rates,
                required String source,
                required String fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredRatesCompanion.insert(
                base: base,
                rates: rates,
                source: source,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoredRatesTable, StoredRate>(table),
                  BaseReferences<
                    _$LocalDatabase,
                    $StoredRatesTable,
                    StoredRate
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredRatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $StoredRatesTable,
      StoredRate,
      $$StoredRatesTableFilterComposer,
      $$StoredRatesTableOrderingComposer,
      $$StoredRatesTableAnnotationComposer,
      $$StoredRatesTableCreateCompanionBuilder,
      $$StoredRatesTableUpdateCompanionBuilder,
      (
        StoredRate,
        BaseReferences<_$LocalDatabase, $StoredRatesTable, StoredRate>,
      ),
      StoredRate,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer
    extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$LocalDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$LocalDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$LocalDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaRow>(table),
                  BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$LocalDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db, _db.currencies);
  $$TemplateItemsTableTableManager get templateItems =>
      $$TemplateItemsTableTableManager(_db, _db.templateItems);
  $$MonthsTableTableManager get months =>
      $$MonthsTableTableManager(_db, _db.months);
  $$MonthItemsTableTableManager get monthItems =>
      $$MonthItemsTableTableManager(_db, _db.monthItems);
  $$DailySpendsTableTableManager get dailySpends =>
      $$DailySpendsTableTableManager(_db, _db.dailySpends);
  $$StoredRatesTableTableManager get storedRates =>
      $$StoredRatesTableTableManager(_db, _db.storedRates);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
