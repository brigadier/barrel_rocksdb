%%%-------------------------------------------------------------------
%%% @author benoitc
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. May 2016 15:28
%%%-------------------------------------------------------------------
-module(dht_eqc).
-author("benoitc").

-compile([export_all/1]).

-ifdef(EQC).


qc(P) ->
  ?assert(eqc:quickcheck(?QC_OUT(P))).

keys() ->
  eqc_gen:non_empty(list(eqc_gen:non_empty(binary()))).

values() ->
  eqc_gen:non_empty(list(binary())).

ops(Keys, Values) ->
  {oneof([put, delete]), oneof(Keys), oneof(Values)}.

apply_kv_ops([], _Ref, Acc0) ->
  Acc0;
apply_kv_ops([{put, K, V} | Rest], Ref, Acc0) ->
  ok = erocksdb:put(Ref, K, V, []),
  apply_kv_ops(Rest, Ref, orddict:store(K, V, Acc0));
apply_kv_ops([{delete, K, _} | Rest], Ref, Acc0) ->
  ok = erocksdb:delete(Ref, K, []),
  apply_kv_ops(Rest, Ref, orddict:store(K, deleted, Acc0)).

prop_put_delete() ->
  ?LET({Keys, Values}, {keys(), values()},
    ?FORALL(Ops, eqc_gen:non_empty(list(ops(Keys, Values))),
      begin
        ?cmd("rm -rf /tmp/erocksdb.putdelete.qc"),
        {ok, Ref} = erocksdb:open("/tmp/erocksdb.putdelete.qc",
          [{create_if_missing, true}], [], 10000),
        Model = apply_kv_ops(Ops, Ref, []),

        %% Valdiate that all deleted values return not_found
        F = fun({K, deleted}) ->
          ?assertEqual(not_found, erocksdb:get(Ref, K, []));
          ({K, V}) ->
            ?assertEqual({ok, V}, erocksdb:get(Ref, K, []))
            end,
        lists:map(F, Model),

        %% Validate that a fold returns sorted values
        Actual = lists:reverse(fold(Ref, fun({K, V}, Acc) -> [{K, V} | Acc] end,
          [], [])),
        ?assertEqual([{K, V} || {K, V} <- Model, V /= deleted],
          Actual),
        ok = erocksdb:close(Ref),
        true
      end)).

prop_put_delete_test_() ->
  Timeout1 = 10,
  Timeout2 = 15,
  %% We use the ?ALWAYS(300, ...) wrapper around the second test as a
  %% regression test.
  [{timeout,  3 * Timeout1,
    {"No ?ALWAYS()", fun() -> qc(eqc:testing_time(Timeout1,prop_put_delete())) end}},
    {timeout, 10 * Timeout2,
      {"With ?ALWAYS()", fun() -> qc(eqc:testing_time(Timeout2,?ALWAYS(150,prop_put_delete()))) end}}].

-endif.