-module(scout).
-export([start/3]).

% B = Ballot number
start(Leader, Acceptors, B) ->
	[A ! {p1a, self(), B} || A <- Acceptors],
	next(Leader, Acceptors, sets:from_list(Acceptors), sets:new(), B).

next(Leader, Acceptors, Waitfor, Pvals, B) ->
	receive
		{p1b, A, B2, R} ->
			if
				B2 =:= B ->
					Pvals2 = sets:union(Pvals, R),
					Waitfor2 = sets:del_element(A, Waitfor),
					case sets:size(Waitfor2) < length(Acceptors) / 2 of
						true -> Leader ! {adopted, B, Pvals2};
						false -> next(Leader, Acceptors, Waitfor2, Pvals2, B)
					end;
				true ->
					Leader ! {preempted, B2}
			end
	end.


	