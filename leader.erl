-module(leader).
-export([start/0]).


start() ->
	receive
		{bind, Acceptors, Replicas} ->
			Ballot = {0, self()},
			Active = false,
			Proposals = sets:new(),
			spawn(scout, start, [self(), Acceptors, Ballot]),
			next(Ballot, Active, Proposals, Acceptors, Replicas)
	end.


next(Ballot, Active, Proposals, Acceptors, Replicas) ->
	receive
		{propose, S, C} ->
			case lists:any(fun({S2, _}) -> S2 =:= S end, sets:to_list(Proposals)) of
				false ->
					Proposals2 = sets:add_element({S, C}, Proposals),
					case Active of
						true 	-> spawn(commander, start, [self(), Acceptors, Replicas, {Ballot, S, C}]);
						false -> ok
					end;
				true -> Proposals2 = Proposals
			end,
			next(Ballot, Active, Proposals2, Acceptors, Replicas);
		{adopted, NewBallot, Pvals} ->
			% TODO: (this isn't in the paper) NewBallot should be equal to Ballot
			case NewBallot =/= Ballot of
				true -> io:format("SHOULD NOT BE HAPPENING. Adopted Ballot not the same as current ballot.");
				false -> ok
			end,
			MaxPvals = pmax(sets:to_list(Pvals)),
			Proposals2 = update(sets:to_list(Proposals), MaxPvals),
			[spawn(commander, start, [self(), Acceptors, Replicas, {NewBallot, S, C}]) || {S, C} <- sets:to_list(Proposals2)],
			next(NewBallot, true, Proposals2, Acceptors, Replicas);
		{preempted, {R, _}=OtherBallot} ->
			case OtherBallot > Ballot of
				true ->
					NewBallot = {R, self()},
					spawn(scout, start, [self(), Acceptors, NewBallot]),
					next(NewBallot, false, Proposals, Acceptors, Replicas);
				false ->
					next(Ballot, Active, Proposals, Acceptors, Replicas)
			end
	end.


pmax(Pvals) ->
	% io:format("Pvals = ~p\n", Pvals),
	GroupBySlot = group_by_slot(Pvals),
	lists:map(fun(L) -> {_, S, C} = lists:max(L), {S, C} end, GroupBySlot).
	
group_by_slot(Pvals) ->
	group_by_slot(lists:sort(fun({_, S, _}, {_, S2, _}) -> S > S2 end, Pvals), []).

group_by_slot([], Lists) -> Lists;
group_by_slot([{_, S, _} | _]=List, Lists) ->
	{L, Remainder} = lists:splitwith(fun({_, S2, _}) -> S2 =:= S end, List),
	group_by_slot(Remainder, Lists ++ [L]).

update(Proposals, Pvals) ->
	update(lists:sort(Proposals), lists:sort(Pvals), []).

update([], [], Acc) -> sets:from_list(Acc);
update([], Pvals, Acc) -> sets:from_list(Acc ++ Pvals);
update(Proposals, [], Acc) -> sets:from_list(Acc ++ Proposals);
update([{S, C}|PropTail]=Proposals, [{S2, C2}|PVTail]=Pvals, Acc) ->
	if
		S =:= S2 ->
			update(PropTail, Pvals, Acc);
		S < S2 ->
			update(PropTail, Pvals, Acc ++ [{S, C}]);
		true ->
			update(Proposals, PVTail, Acc ++ [{S2, C2}])
	end.

% T1 = [{1,1}, {4, 3}, {200, 6}].
% T2 = [{2,4}, {3, 8}, {5, 9}].
randtuples() ->
	Len = 10,
	[{rand:uniform(10), rand:uniform(10)} || _ <- lists:seq(1, Len)].

	