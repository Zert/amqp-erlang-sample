-module(client_ep).
-author('Maxim Treskin').

-behaviour(gen_fsm).

-include("client.hrl").

-include_lib("rabbitmq_server/include/rabbit.hrl").
-include_lib("rabbitmq_server/include/rabbit_framing.hrl").

-export([start_link/1]).

-export([
         init/1,
         handle_event/3,
         handle_sync_event/4,
         handle_info/3,
         terminate/3,
         code_change/4
        ]).

-export([
         state_init/2
        ]).


-record(state, {
         }).


start_link(Args) ->
    gen_fsm:start_link(?MODULE, Args, []).

%% @private
init(Args) ->
    ?DBG("Args: ~p", [Args]),
    {ok, state_init, #state{}}.

%% @private
handle_event(Event, StateName, StateData) ->
    ?ERR("Unknown Event: ~p (~p): ~p", [Event, StateName, StateData]),
    {next_state, StateName, StateData}.

%% @private
handle_sync_event(Event, _From, StateName, StateData) ->
    ?DBG("Handle Sync Event", []),
    {stop, {StateName, undefined_event, Event}, StateData}.

%% @private
handle_info(Info, StateName, StateData) ->
    ?DBG("Handle Info: ~p, ~p, ~p", [Info, StateName, StateData]),
    {next_state, StateName, StateData}.

%% @private
terminate(Reason, StateName, #state{} = State) ->
    ?DBG("Deleting: ~p, ~p~n~p", [Reason, StateName, State]),
    ok.

%% @private
code_change(_OldVsn, StateName, StateData, _Extra) ->
    ?DBG("Code Change", []),
    {ok, StateName, StateData}.


state_init(Msg, State) ->
    ?DBG("StateInit: ~p, ~p", [Msg, State]),
    {next_state, state_init, State}.



