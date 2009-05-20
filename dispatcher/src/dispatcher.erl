-module(dispatcher).
-author('Maxim Treskin').

-include("dispatcher.hrl").

-export([
         start/0,
         stop/0,
         off/0,
         restart/0,
         reload_module/1,
         reload_code/0
        ]).

start() ->
    application:start(dispatcher).

stop() ->
    application:stop(dispatcher).

restart() ->
    init:restart().

off() ->
    init:stop(),
    halt().

reload_module(M) ->
    {ok, Keys} = application:get_all_key(?MODULE),
    Modules =
        case lists:keysearch(modules, 1, Keys) of
            {value, {modules, Mods}} -> Mods;
            _ -> []
        end,
    case lists:member(M, Modules) of
        true ->
            code:purge(M),
            code:load_file(M),
            ?INFO("Reload: ~p~n", [M]);
        _ ->
            ?ERR("Module ~p is not belongs to DISPATCHER~n", [M])
    end,
    ok.


reload_code() ->
    {ok, Keys} = application:get_all_key(?MODULE),
    Modules =
        case lists:keysearch(modules, 1, Keys) of
            {value, {modules, Mods}} -> Mods;
            _ -> []
        end,
    Reload = fun(Module) ->
                     code:purge(Module),
                     code:load_file(Module),
                     ?INFO("	~p~n", [Module])
             end,
    ?INFO("DISPATCHER Reloading:", []),
    [Reload(Mod) || Mod <- Modules],
    ok.
