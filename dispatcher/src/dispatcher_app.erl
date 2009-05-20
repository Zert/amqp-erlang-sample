-module(dispatcher_app).
-author('Maxim Treskin').

-behaviour(application).

-include("dispatcher.hrl").

%% Internal API
-export([
         start_ep_proc/1,
         get_app_env/2
        ]).

%% Application and Supervisor callbacks
-export([start/2, stop/1, init/1]).

-define(MAX_RESTART,    5).
-define(MAX_TIME,      60).

%% A startup function for spawning new call FSM.
start_ep_proc(Args) ->
    supervisor:start_child(dispatcher_ep_sup, [Args]).

%%----------------------------------------------------------------------
%% Application behaviour callbacks
%%----------------------------------------------------------------------
start(Application, Type) ->
    ?INFO("Starting: ~p ~p", [Application, Type]),
    supervisor:start_link({local, ?MODULE}, ?MODULE, [tt]).

stop(_S) ->
    ok.

%%----------------------------------------------------------------------
%% Supervisor behaviour callbacks
%%----------------------------------------------------------------------

init([dispatcher_ep]) ->
    {ok,
     {_SupFlags = {simple_one_for_one, ?MAX_RESTART, ?MAX_TIME},
      [
       %% EP Client
       { undefined, {dispatcher_ep, start_link, []},
         temporary, 2000, worker, [] }
      ]
     }
    };
init([tt]) ->
    {ok,
     {_SupFlags = {one_for_one, ?MAX_RESTART, ?MAX_TIME},
      [
       %% Broker server
       { dispatcher_broker_sup, {dispatcher_broker, start_link, []},
         permanent, 2000, worker, [dispatcher_broker] },
       %% EP instance supervisor
       { dispatcher_ep_sup, {supervisor,start_link,
                      [{local, dispatcher_ep_sup},
                       ?MODULE, [dispatcher_ep]]},
         permanent, infinity, supervisor, [] }

      ]
     }
    }.

%%----------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------
get_app_env(Opt, Default) ->
    case application:get_env(Opt) of
        {ok, Val} -> Val;
        _ -> Default
    end.
