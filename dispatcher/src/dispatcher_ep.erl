-module(dispatcher_ep).
-author('Maxim Treskin').

-behaviour(gen_fsm).

-include("dispatcher.hrl").

-include_lib("rabbitmq_client/include/amqp_client.hrl").

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
          channel,
          croute,
          tag
         }).


start_link(Args) ->
    gen_fsm:start_link(?MODULE, Args, []).

%% @private
init(Args) ->
    ?DBG("Args: ~p", [Args]),
    Uniq = proplists:get_value(key, Args),
    CRoutKey = <<"client.main.", Uniq/binary>>,
    SRoutKey = Queue = <<"client.serv.", Uniq/binary>>,

    case proplists:get_value(channel, Args) of
        Channel when is_pid(Channel) ->
            Exch = proplists:get_value(exchange, Args),

            amqp_channel:call(
              Channel, #'queue.declare'{queue       = Queue,
                                        auto_delete = true}),

            amqp_channel:call(
              Channel, #'queue.bind'{queue       = Queue,
                                     routing_key = SRoutKey,
                                     exchange    = Exch}),
            Tag = amqp_channel:subscribe(
                    Channel, #'basic.consume'{queue = Queue},
                    self()),
            {ok, state_init, #state{channel = Channel,
                                    croute = CRoutKey,
                                    tag = Tag
                                   }};
        _ ->
            ?ERR("Undefined AMQP Channel for ~p", [CRoutKey]),
            {stop, normal}
    end.

%% @private
handle_event(Event, StateName, StateData) ->
    ?ERR("Unknown Event: ~p (~p): ~p", [Event, StateName, StateData]),
    {next_state, StateName, StateData}.

%% @private
handle_sync_event(Event, _From, StateName, StateData) ->
    ?DBG("Handle Sync Event", []),
    {stop, {StateName, undefined_event, Event}, StateData}.

%% @private
handle_info(#'basic.consume_ok'{consumer_tag = CTag}, StateName,
            #state{} = State) ->
    ?DBG("Consumer Tag: ~p", [CTag]),
    {next_state, StateName, State};
handle_info({#'basic.deliver'{consumer_tag = CTag,
                              delivery_tag = DeliveryTag,
                              exchange = Exch,
                              routing_key = RK},
             #amqp_msg{payload = Data} = Content},
            StateName,
            #state{channel = Channel, croute = CRoutKey} = StateData) ->
    ?DBG("ConsumerTag: ~p"
         "~nDeliveryTag: ~p"
         "~nExchange: ~p"
         "~nRoutingKey: ~p"
         "~nContent: ~p"
         "~n",
         [CTag, DeliveryTag, Exch, RK, Content]),
    D = try binary_to_term(Data) catch _:_ -> error end,
    ?INFO("Data: ~p", [D]),
    Reply = term_to_binary({reply, D}),
    amqp_channel:call(Channel,
                      #'basic.publish'{exchange    = Exch,
                                       routing_key = CRoutKey},
                      #amqp_msg{props   = #'P_basic'{},
                                payload = Reply}),
    {next_state, StateName, StateData};
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



