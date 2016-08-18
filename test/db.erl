-module(db).
-compile([export_all/1]).
-include_lib("eunit/include/eunit.hrl").

destroy_reopen(DbName, Options) ->
  _ = erocksdb:destroy(DbName, []),
  os:cmd("rm -rf " ++ DbName),
  {ok, Db} = erocksdb:open(DbName, Options, [], 10000),
  Db.


open_test() -> [{open_test_Z(), l} || l <- lists:seq(1, 20)].
open_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.open.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.open.test", [{create_if_missing, true}], [], 10000),
  true = erocksdb:is_empty(Ref),
  ok = erocksdb:put(Ref, <<"abc">>, <<"123">>, []),
  false = erocksdb:is_empty(Ref),
  {ok, <<"123">>} = erocksdb:get(Ref, <<"abc">>, []),
  {ok, 1} = erocksdb:count(Ref),
  not_found = erocksdb:get(Ref, <<"def">>, []),
  ok = erocksdb:delete(Ref, <<"abc">>, []),
  not_found = erocksdb:get(Ref, <<"abc">>, []),
  true = erocksdb:is_empty(Ref).

fold_test() -> [{fold_test_Z(), l} || l <- lists:seq(1, 20)].
fold_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.fold.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.fold.test", [{create_if_missing, true}], [], 10000),
  ok = erocksdb:put(Ref, <<"def">>, <<"456">>, []),
  ok = erocksdb:put(Ref, <<"abc">>, <<"123">>, []),
  ok = erocksdb:put(Ref, <<"hij">>, <<"789">>, []),
  [{<<"abc">>, <<"123">>},
   {<<"def">>, <<"456">>},
   {<<"hij">>, <<"789">>}] = lists:reverse(erocksdb:fold(Ref,
                                                         fun({K, V}, Acc) ->
                                                             [{K, V} | Acc]
                                                         end,
                                                         [], [])).

fold_keys_test() -> [{fold_keys_test_Z(), l} || l <- lists:seq(1, 20)].
fold_keys_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.fold.keys.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.fold.keys.test", [{create_if_missing, true}], [], 10000),
  ok = erocksdb:put(Ref, <<"def">>, <<"456">>, []),
  ok = erocksdb:put(Ref, <<"abc">>, <<"123">>, []),
  ok = erocksdb:put(Ref, <<"hij">>, <<"789">>, []),
  [<<"abc">>, <<"def">>, <<"hij">>] = lists:reverse(erocksdb:fold_keys(Ref,
                                                                       fun(K, Acc) -> [K | Acc] end,
                                                                       [], [])).

destroy_test() -> [{destroy_test_Z(), l} || l <- lists:seq(1, 20)].
destroy_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.destroy.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.destroy.test", [{create_if_missing, true}], [], 10000),
  ok = erocksdb:put(Ref, <<"def">>, <<"456">>, []),
  {ok, <<"456">>} = erocksdb:get(Ref, <<"def">>, []),
  erocksdb:close(Ref),
  ok = erocksdb:destroy("/tmp/erocksdb.destroy.test", []),
  {error, {db_open, _}} = erocksdb:open("/tmp/erocksdb.destroy.test", [{error_if_exists, true}], [], 10000).

compression_test() -> [{compression_test_Z(), l} || l <- lists:seq(1, 20)].
compression_test_Z() ->
  CompressibleData = list_to_binary([0 || _X <- lists:seq(1,20)]),
  os:cmd("rm -rf /tmp/erocksdb.compress.0 /tmp/erocksdb.compress.1"),
  {ok, Ref0} = erocksdb:open("/tmp/erocksdb.compress.0", [{create_if_missing, true}],
                             [{compression, none}], 10000),
  [ok = erocksdb:put(Ref0, <<I:64/unsigned>>, CompressibleData, [{sync, true}]) ||
   I <- lists:seq(1,10)],
  {ok, Ref1} = erocksdb:open("/tmp/erocksdb.compress.1", [{create_if_missing, true}],
                             [{compression, snappy}], 10000),
  [ok = erocksdb:put(Ref1, <<I:64/unsigned>>, CompressibleData, [{sync, true}]) ||
   I <- lists:seq(1,10)],
  %% Check both of the LOG files created to see if the compression option was correctly
  %% passed down
  MatchCompressOption =
  fun(File, Expected) ->
      {ok, Contents} = file:read_file(File),
      case re:run(Contents, "Options.compression: " ++ Expected) of
        {match, _} -> match;
        nomatch -> nomatch
      end
  end,
  Log0Option = MatchCompressOption("/tmp/erocksdb.compress.0/LOG", "0"),
  Log1Option = MatchCompressOption("/tmp/erocksdb.compress.1/LOG", "1"),
  ?assert(Log0Option =:= match andalso Log1Option =:= match).

close_test() -> [{close_test_Z(), l} || l <- lists:seq(1, 20)].
close_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.close.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.close.test", [{create_if_missing, true}], [], 10000),
  ?assertEqual(ok, erocksdb:close(Ref)),
  ?assertEqual({error, einval}, erocksdb:close(Ref)).

close_fold_test() -> [{close_fold_test_Z(), l} || l <- lists:seq(1, 20)].
close_fold_test_Z() ->
  os:cmd("rm -rf /tmp/erocksdb.close_fold.test"),
  {ok, Ref} = erocksdb:open("/tmp/erocksdb.close_fold.test", [{create_if_missing, true}], [], 10000),
  ok = erocksdb:put(Ref, <<"k">>,<<"v">>,[]),
  ?assertException(throw, {iterator_closed, ok}, % ok is returned by close as the acc
                   erocksdb:fold(Ref, fun(_,_A) -> erocksdb:close(Ref) end, undefined, [])).


flush_test() ->
  Db = destroy_reopen("test.db", [{create_if_missing, true}]),
  ok = erocksdb:put(Db, <<"a">>, <<"1">>, []),
  ok = erocksdb:flush(Db),
  {ok, <<"1">>} = erocksdb:get(Db, <<"a">>, []),
  erocksdb:close(Db).


randomstring(Len) ->
  list_to_binary([rand:uniform(95) || _I <- lists:seq(0, Len - 1)]).

key(I) when is_integer(I) ->
  <<I:128/unsigned>>.


approximate_size_test() ->
  Db = destroy_reopen("erocksdb_approximate_size.db",
                      [{create_if_missing, true},
                       {write_buffer_size, 100000000},
                       {compression, none}]),

  try
    N = 128,
    rand:seed_s(exsplus),
    lists:foreach(fun(I) ->
                      ok = erocksdb:put(Db, key(I), randomstring(1024), [])
                  end, lists:seq(0, N)),

    Start = key(50),
    End = key(60),
    Size = erocksdb:get_approximate_size(Db, Start, End, true),
    ?assert(Size >= 6000),
    ?assert(Size =< 204800),
    Size2 = erocksdb:get_approximate_size(Db, Start, End, false),
    ?assertEqual(0, Size2),
    Start2 = key(500),
    End2 = key(600),
    Size3 = erocksdb:get_approximate_size(Db, Start2, End2, true),
    ?assertEqual(0, Size3),

    lists:foreach(fun(I) ->
                      ok = erocksdb:put(Db, key(I+1000), randomstring(1024), [])
                  end, lists:seq(0, N)),

    Size4 = erocksdb:get_approximate_size(Db, Start2, End2, true),
    ?assertEqual(0, Size4),
    Start3 = key(1000),
    End3 = key(1020),
    Size5 = erocksdb:get_approximate_size(Db, Start3, End3, true),


    ?assert(Size5 >= 6000)
  after
    erocksdb:close(Db)
  end.

