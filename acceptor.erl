-module(acceptor).
-export([start/0]).

start() ->
	next(sets:new(), {-1, -1}).

next(Accepted, Ballot_num) ->
	receive
		{p1a, Leader, B} ->
			Ballot_num2 = erlang:max(B, Ballot_num),
			Leader ! {p1b, self(), Ballot_num2, Accepted},
			next(Accepted, Ballot_num2);
		{p2a, Leader, {B, _S, _C}=M} ->
			case B =:= Ballot_num of
				true 	-> Accepted2 = sets:add_element(M, Accepted);
				false 	-> Accepted2 = Accepted
			end,
			Leader ! {p2b, self(), Ballot_num},
			next(Accepted2, Ballot_num)
	end.