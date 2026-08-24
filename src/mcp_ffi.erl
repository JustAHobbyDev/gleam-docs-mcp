-module(mcp_ffi).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch]).
-export([is_binary/1, is_integer/1, is_float/1, is_boolean/1, is_list/1, is_map/1, get_map_value/2, map_to_list/1, list_to_gleam/1, read_line/0, identity_decoder/0, identity/1]).

is_binary(V) -> erlang:is_binary(V).
is_integer(V) -> erlang:is_integer(V).
is_float(V) -> erlang:is_float(V).
is_boolean(V) -> erlang:is_boolean(V).
is_list(V) -> erlang:is_list(V).
is_map(V) -> erlang:is_map(V).

get_map_value(Map, Key) when erlang:is_map(Map) ->
    case maps:find(Key, Map) of
        {ok, Value} -> {ok, Value};
        error -> {error, nil}
    end;
get_map_value(_, _) -> {error, nil}.

map_to_list(Map) when erlang:is_map(Map) -> maps:to_list(Map).

list_to_gleam(Value) -> Value.

read_line() ->
    case io:get_line("") of
        eof -> {error, nil};
        {error, _} -> {error, nil};
        Data -> {ok, unicode:characters_to_binary(string:trim(Data))}
    end.

identity_decoder() ->
    fun(X) -> {ok, X} end.

identity(X) -> X.
