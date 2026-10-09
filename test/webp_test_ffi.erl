-module(webp_test_ffi).
-export([fixture_expectations/0, sha256/1]).

% Pillow-generated expectations keep decoder tests independent of our encoder.
% OTP 27+ supplies JSON decoding without adding a test-only package dependency.
fixture_expectations() ->
  {ok, Bytes} = file:read_file("test/assets/webp/pixels.json"),
  [{Name, maps:get(<<"width">>, Spec), maps:get(<<"height">>, Spec),
    maps:get(<<"channels">>, Spec), maps:get(<<"sha256">>, Spec)}
   || {Name, Spec} <- maps:to_list(json:decode(Bytes))].

% Match the lowercase hexadecimal hashes recorded by Python's hashlib.
sha256(Bytes) ->
  string:lowercase(binary:encode_hex(crypto:hash(sha256, Bytes))).
