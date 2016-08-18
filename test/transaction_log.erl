%%%-------------------------------------------------------------------
%%% @author benoitc
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. May 2016 22:42
%%%-------------------------------------------------------------------
-module(transaction_log).
-author("benoitc").

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
  Db1 = destroy_reopen("test1.db", [{create_if_missing, true}]),

  ok = erocksdb:put(Db, <<"a">>, <<"v1">>, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(1, erocksdb:get_latest_sequence_number(Db)),
  ?assertEqual(0, erocksdb:get_latest_sequence_number(Db1)),

  {ok, Itr} = erocksdb:updates_iterator(Db, 0),
  {ok, Last, TransactionBin} = erocksdb:next_binary_update(Itr),
  ?assertEqual(1, Last),

  ?assertEqual(not_found, erocksdb:get(Db1, <<"a">>, [])),
  ok = erocksdb:write_binary_update(Db1, TransactionBin, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual(1, erocksdb:get_latest_sequence_number(Db1)),
  ok = erocksdb:close_updates_iterator(Itr),

  close_destroy(Db, "test.db"),
  close_destroy(Db1, "test1.db"),
  ok.

iterator_test() ->
  Db = destroy_reopen("test.db", [{create_if_missing, true}]),
  Db1 = destroy_reopen("test1.db", [{create_if_missing, true}]),

  ok = erocksdb:put(Db, <<"a">>, <<"v1">>, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db, <<"a">>, [])),
  ?assertEqual(1, erocksdb:get_latest_sequence_number(Db)),

  ok = erocksdb:put(Db, <<"b">>, <<"v2">>, []),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db, <<"b">>, [])),
  ?assertEqual(2, erocksdb:get_latest_sequence_number(Db)),

  {ok, Itr} = erocksdb:updates_iterator(Db, 0),
  {ok, Last, TransactionBin} = erocksdb:next_binary_update(Itr),
  ?assertEqual(1, Last),

  ?assertEqual(not_found, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"b">>, [])),


  ok = erocksdb:write_binary_update(Db1, TransactionBin, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"b">>, [])),

  {ok, Last2, TransactionBin2} = erocksdb:next_binary_update(Itr),
  ?assertEqual(2, Last2),
  ok = erocksdb:write_binary_update(Db1, TransactionBin2, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db1, <<"b">>, [])),

  ?assertEqual({error, invalid_iterator}, erocksdb:next_binary_update(Itr)),

  ok = erocksdb:close_updates_iterator(Itr),

  close_destroy(Db, "test.db"),
  close_destroy(Db1, "test1.db"),
  ok.


iterator_with_batch_test() ->

  Db = destroy_reopen("test.db", [{create_if_missing, true}]),
  Db1 = destroy_reopen("test1.db", [{create_if_missing, true}]),

  ok = erocksdb:write(Db, [{put, <<"a">>, <<"v1">>},
    {put, <<"b">>, <<"v2">>}], []),
  ?assertEqual(2, erocksdb:get_latest_sequence_number(Db)),

  ok = erocksdb:write(Db, [{put, <<"c">>, <<"v3">>}, {delete, <<"a">>}], []),

  ?assertEqual(4, erocksdb:get_latest_sequence_number(Db)),

  {ok, Itr} = erocksdb:updates_iterator(Db, 0),

  {ok, Last, TransactionBin} = erocksdb:next_binary_update(Itr),
  ?assertEqual(1, Last),
  ok = erocksdb:write_binary_update(Db1, TransactionBin, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db1, <<"b">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"c">>, [])),
  ?assertEqual(2, erocksdb:get_latest_sequence_number(Db1)),

  {ok, Last2, TransactionBin2} = erocksdb:next_binary_update(Itr),
  ?assertEqual(3, Last2),
  ok = erocksdb:write_binary_update(Db1, TransactionBin2, []),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db1, <<"b">>, [])),
  ?assertEqual({ok, <<"v3">>}, erocksdb:get(Db1, <<"c">>, [])),

  ?assertEqual(4, erocksdb:get_latest_sequence_number(Db1)),

  close_destroy(Db, "test.db"),
  close_destroy(Db1, "test1.db"),
  ok.

iterator_with_batch2_test() ->

  Db = destroy_reopen("test.db", [{create_if_missing, true}]),
  Db1 = destroy_reopen("test1.db", [{create_if_missing, true}]),

  W1 = [{put, <<"a">>, <<"v1">>}, {put, <<"b">>, <<"v2">>}],
  W2 = [{put, <<"c">>, <<"v3">>}, {delete, <<"a">>}],

  ok = erocksdb:write(Db, W1, []),
  ?assertEqual(2, erocksdb:get_latest_sequence_number(Db)),

  ok = erocksdb:write(Db, W2, []),

  ?assertEqual(4, erocksdb:get_latest_sequence_number(Db)),

  {ok, Itr} = erocksdb:updates_iterator(Db, 0),

  {ok, Last, Log, BinLog} = erocksdb:next_update(Itr),
  ?assertEqual(1, Last),
  ?assertEqual(W1, Log),

  ok = erocksdb:write_binary_update(Db1, BinLog, []),
  ?assertEqual({ok, <<"v1">>}, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db1, <<"b">>, [])),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"c">>, [])),
  ?assertEqual(2, erocksdb:get_latest_sequence_number(Db1)),


  {ok, Last2, Log2, BinLog2} = erocksdb:next_update(Itr),
  ?assertEqual(3, Last2),
  ?assertEqual(W2, Log2),
  ok = erocksdb:write_binary_update(Db1, BinLog2, []),
  ?assertEqual(not_found, erocksdb:get(Db1, <<"a">>, [])),
  ?assertEqual({ok, <<"v2">>}, erocksdb:get(Db1, <<"b">>, [])),
  ?assertEqual({ok, <<"v3">>}, erocksdb:get(Db1, <<"c">>, [])),
  ?assertEqual(4, erocksdb:get_latest_sequence_number(Db1)),

  close_destroy(Db, "test.db"),
  close_destroy(Db1, "test1.db"),
  ok.






