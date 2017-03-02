-module(commander).
-export([start/4]).

% B = Ballot number
% S = Slot number
% C = Command
% M = {B, S, C}
start(Leader, Acceptors, Replicas, M) ->
	[A ! {p2a, self(), M} || A <- Acceptors],
	next(Leader, Acceptors, sets:from_list(Acceptors), Replicas, M).

next(Leader, Acceptors, Waitfor, Replicas, {B, S, C}=M) ->
	receive
		{p2b, A, B2} ->
			case B2 =:= B of
				true ->
					Waitfor2 = sets:del_element(A, Waitfor),
					case sets:size(Waitfor2) < length(Acceptors) / 2 of
						true -> [R ! {decision, S, C} || R <- Replicas];
						false -> next(Leader, Acceptors, Waitfor2, Replicas, M)
					end;
				false -> Leader ! {preempted, B2}
			end
	end.
