% Jaime Rodriguez (jr1713) and Ignacio Navarro (in714)

%%% distributed algorithms, n.dulay 27 feb 17
%%% coursework 2, paxos made moderately complex

-module(replica).
-export([start/1]).

start(Database) ->
  receive
    {bind, Leaders} -> 
      % TODO:
      % State = todo
      {SlotIn, SlotOut} = {1, 1},
      {Requests, Proposals, Decisions} = {sets:new(), sets:new(), sets:new()},
      next(SlotIn, SlotOut, Requests, Proposals, Decisions, Leaders, Database)
  end.

next(SlotIn, SlotOut, Requests, Proposals, Decisions, Leaders, Database) ->
  receive
    {request, C} ->      % request from client
      Decisions2 = Decisions,
      {SlotOut2, Requests2, Proposals2} =
        {SlotOut, sets:add_element(C, Requests), Proposals};
    {decision, S, C} ->  % decision from commander
      Decisions2 = sets:add_element({S, C}, Decisions),
      {SlotOut2, Requests2, Proposals2} =
        decide(SlotOut, Decisions, Requests, Proposals, Database)
  end,
  {SlotIn2, Requests3, Proposals3} =
    propose(SlotIn, SlotOut2, Requests2, Proposals2, Decisions2, Leaders),
  next(SlotIn2, SlotOut2, Requests3, Proposals3, Decisions2, Leaders, Database).

propose(SlotIn, SlotOut, Requests, Proposals, Decisions, Leaders) ->
  WINDOW = 5,
  case (SlotIn < SlotOut + WINDOW) and (sets:size(Requests) =/= 0) of
    true ->
      % Ignore reconfig commands
      case lists:any(fun({S, _}) -> S =:= SlotIn end, sets:to_list(Decisions)) of
        false ->
          % Non empty by case assumption
          R = hd(sets:to_list(Requests)),
          Requests2 = sets:del_element(R, Requests),
          Proposals2 = sets:add_element({SlotIn, R}, Proposals),
          [Leader ! {propose, SlotIn, R} || Leader <- Leaders],
          {SlotIn + 1, Requests2, Proposals2};
        true ->
          {SlotIn + 1, Requests, Proposals}
      end;
    false -> {SlotIn, Requests, Proposals}
  end.

perform({Client, Cid, Op}=C, SlotOut, Decisions, Database) ->
  Ds = sets:filter(fun({S, C2}) ->(S < SlotOut) and (C =:= C2) end, Decisions),
  case sets:size(Ds) =/= 0 of
    false ->
      Database ! {execute, Op},
      Client ! {response, Cid, ok};
    true -> ok
  end.

decide(SlotOut, Decisions, Requests, Proposals, Database) ->
  Ds = sets:filter(fun({S, _}) -> S =:= SlotOut end, Decisions),
  case sets:size(Ds) =:= 0 of
    true  -> {SlotOut, Requests, Proposals};
    false ->
      {_, C} = hd(sets:to_list(Ds)),
      Ps = sets:filter(fun({S, _}) -> S =:= SlotOut end, Proposals),
      case sets:size(Ps) =:= 0 of
        false ->
          {S2, C2} = hd(sets:to_list(Ps)),
          Proposals2 = sets:del_element({S2, C2}, Proposals),
          case C2 =:= C of
            false -> Requests2 = sets:add_element(C2, Requests);
            true  -> Requests2 = Requests
          end;
        true ->
          Proposals2 = Proposals,
          Requests2 = Requests
      end,
      perform(C, SlotOut, Decisions, Database),
      decide(SlotOut + 1, Decisions, Requests2, Proposals2, Database)
  end.


