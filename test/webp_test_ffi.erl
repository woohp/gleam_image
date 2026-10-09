-module(webp_test_ffi).
-export([fixture_expectations/0, sha256/1]).

fixture_expectations() ->
  {ok, Bytes} = file:read_file("test/assets/webp/pixels.json"),
  [{Name, maps:get(<<"width">>, Spec), maps:get(<<"height">>, Spec),
    maps:get(<<"channels">>, Spec), maps:get(<<"sha256">>, Spec)}
   || {Name, Spec} <- maps:to_list(json:decode(Bytes))].

sha256(Bytes) ->
  string:lowercase(binary:encode_hex(crypto:hash(sha256, Bytes))).
