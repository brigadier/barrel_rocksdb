-module(batch).

-compile([export_all/1]).
-include_lib("eunit/include/eunit.hrl").

destroy_reopen(DbName, Options) ->
  _ = erocksdb:destroy(DbName, []),
  {ok, Db} = erocksdb:open(DbName, Options, [], 10000),
  Db.

close_destroy(Db, DbName) ->
  erocksdb:close(Db),
  erocksdb:destroy(DbName, []).

basic_test() ->
  Db = destroy_reopen("test.db", [{create_if_missing, true}]),

  {ok, Batch} = erocksdb:batch(),

  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ?assertEqual(2, erocksdb:batchcount(Batch)),

  ?assertEqual(not_found, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:write_batch(Db, Batch, []),

  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:close_batch(Batch),

  close_destroy(Db, "test.db"),
  ok.

delete_test() ->
  Db = destroy_reopen("test.db", [{create_if_missing, true}]),

  {ok, Batch} = erocksdb:batch(),

  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ok = erocksdb:batchdelete(Batch, <<"b">>),
  ?assertEqual(3, erocksdb:batchcount(Batch)),

  ?assertEqual(not_found, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:write_batch(Db, Batch, []),

  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:close_batch(Batch),

  close_destroy(Db, "test.db"),
  ok.

delete_with_notfound_test() ->
  Db = destroy_reopen("test.db", [{create_if_missing, true}]),

  {ok, Batch} = erocksdb:batch(),

  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ok = erocksdb:batchdelete(Batch, <<"c">>),
  ?assertEqual(3, erocksdb:batchcount(Batch)),

  ?assertEqual(not_found, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:write_batch(Db, Batch, []),

  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db, <<"b">>, [])),

  ok = erocksdb:close_batch(Batch),

  close_destroy(Db, "test.db"),
  ok.

tolist_test() ->
  {ok, Batch} = erocksdb:batch(),
  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ?assertEqual(2, erocksdb:batchcount(Batch)),
  ?assertEqual([{put, <<"a">>, <<"v1">>}, {put, <<"b">>, <<"v2">>}], erocksdb:batchtolist(Batch)),
  ok = erocksdb:close_batch(Batch),
  ok.

rollback_test() ->
  {ok, Batch} = erocksdb:batch(),
  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ok = erocksdb:batchsavepoint(Batch),
  ok = erocksdb:batchput(Batch, <<"c">>, <<"v3">>),
  ?assertEqual(3, erocksdb:batchcount(Batch)),
  ?assertEqual([{put, <<"a">>, <<"v1">>},
                {put, <<"b">>, <<"v2">>},
                {put, <<"c">>, <<"v3">>}], erocksdb:batchtolist(Batch)),
  ok = erocksdb:batchrollback(Batch),
  ?assertEqual(2, erocksdb:batchcount(Batch)),
  ?assertEqual([{put, <<"a">>, <<"v1">>},
                {put, <<"b">>, <<"v2">>}], erocksdb:batchtolist(Batch)),
  ok = erocksdb:close_batch(Batch).


rollback_over_savepoint_test() ->
  {ok, Batch} = erocksdb:batch(),
  ok = erocksdb:batchput(Batch, <<"a">>, <<"v1">>),
  ok = erocksdb:batchput(Batch, <<"b">>, <<"v2">>),
  ok = erocksdb:batchsavepoint(Batch),
  ok = erocksdb:batchput(Batch, <<"c">>, <<"v3">>),
  ?assertEqual(3, erocksdb:batchcount(Batch)),
  ?assertEqual([{put, <<"a">>, <<"v1">>},
                {put, <<"b">>, <<"v2">>},
                {put, <<"c">>, <<"v3">>}], erocksdb:batchtolist(Batch)),
  ok = erocksdb:batchrollback(Batch),
  ?assertEqual(2, erocksdb:batchcount(Batch)),
  ?assertEqual([{put, <<"a">>, <<"v1">>},
                {put, <<"b">>, <<"v2">>}], erocksdb:batchtolist(Batch)),

  ?assertMatch({error, _}, erocksdb:batchrollback(Batch)),

  ok = erocksdb:close_batch(Batch).





