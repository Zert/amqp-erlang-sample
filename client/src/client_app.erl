-module(client_app).
-author('Maxim Treskin').

-behaviour(application).

-include("client.hrl").

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
    supervisor:start_child(client_ep_sup, [Args]).

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

init([client_ep]) ->
    {ok,
     {_SupFlags = {simple_one_for_one, ?MAX_RESTART, ?MAX_TIME},
      [
       %% EP Client
       { undefined, {client_ep, start_link, []},
         temporary, 2000, worker, [] }
      ]
     }
    };
init([tt]) ->
    {ok,
     {_SupFlags = {one_for_one, ?MAX_RESTART, ?MAX_TIME},
      [
       %% Broker server
       { client_iface_sup, {client_iface, start_link, []},
         permanent, 2000, worker, [client_iface] },
       %% EP instance supervisor
       { client_ep_sup, {supervisor,start_link,
                      [{local, client_ep_sup},
                       ?MODULE, [client_ep]]},
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
