import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// A scripted stand-in for the PostgREST builders, for repository tests.
// The repository talks to a mocktail `SupabaseClient`; `from(table)` returns a
// FakeTable that records every request (table, operation, chained filters)
// and answers `responses['<table>.<op>']` (or throws it when it is an
// Exception). `rpc` calls are recorded as table `rpc:<name>`, op `rpc`.

/// One request the repository made: `table`, the operation, and the calls
/// chained after it (`eq`, `order`, ...) with their arguments.
class Call {
  Call(this.table, this.op, this.args);
  final String table;
  final String op;
  final List<Object?> args;
  final chain = <String>[];

  @override
  String toString() => '$table.$op($args) ${chain.join(' ')}';
}

/// A scripted PostgREST request: records every chained call and, when
/// awaited, answers with the scripted value or throws the scripted error.
class FakeQuery<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeQuery(this.call, this.world);
  final Call call;
  final FakeWorld world;

  FakeQuery<X> _next<X>(String step, List<Object?> args) {
    call.chain.add('$step(${args.join(',')})');
    return FakeQuery<X>(call, world);
  }

  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) =>
      _next('eq', [column, value]);

  @override
  PostgrestFilterBuilder<T> gte(String column, Object value) =>
      _next('gte', [column, value]);

  @override
  PostgrestFilterBuilder<T> lte(String column, Object value) =>
      _next('lte', [column, value]);

  @override
  PostgrestTransformBuilder<T> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => _next('order', [column, ascending]);

  @override
  PostgrestTransformBuilder<T> limit(int count, {String? referencedTable}) =>
      _next('limit', [count]);

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      _next('select', [columns]);

  @override
  PostgrestTransformBuilder<PostgrestMap> single() => _next('single', []);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) {
    final key = '${call.table}.${call.op}';
    // A scripted sequence answers one request at a time, in order.
    final queue = world.sequences[key];
    final scripted = (queue != null && queue.isNotEmpty)
        ? queue.removeAt(0)
        : world.responses[key];
    final Future<dynamic> result;
    if (scripted is Exception) {
      result = Future<dynamic>.error(scripted);
    } else {
      result = Future<dynamic>.value(scripted);
    }
    return result.then((v) => onValue(v as T), onError: onError);
  }
}

class FakeTable extends Fake implements SupabaseQueryBuilder {
  FakeTable(this.name, this.world);
  final String name;
  final FakeWorld world;

  Call _record(String op, [List<Object?>? args]) {
    final call = Call(name, op, args ?? const []);
    world.calls.add(call);
    return call;
  }

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      FakeQuery<PostgrestList>(_record('select', [columns]), world);

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) => FakeQuery<dynamic>(_record('insert', [values]), world);

  @override
  PostgrestFilterBuilder<dynamic> update(Map<dynamic, dynamic> values) =>
      FakeQuery<dynamic>(_record('update', [values]), world);

  @override
  PostgrestFilterBuilder<dynamic> delete() =>
      FakeQuery<dynamic>(_record('delete'), world);
}

class FakeWorld {
  final responses = <String, Object?>{};
  final sequences = <String, List<Object?>>{};
  final calls = <Call>[];
  List<Call> on(String table, String op) => [
    for (final c in calls)
      if (c.table == table && c.op == op) c,
  ];
}

/// Stubs `client.rpc<String>(name, params: ...)` to the scripted [world].
void stubRpc(SupabaseClient client, FakeWorld world) {
  when(
    () => client.rpc<String>(any(), params: any(named: 'params')),
  ).thenAnswer((i) {
    final name = i.positionalArguments.first as String;
    final call = Call('rpc:$name', 'rpc', [i.namedArguments[#params]]);
    world.calls.add(call);
    return FakeQuery<String>(call, world);
  });
}
