-module(dispatcher_broker).
-author('Maxim Treskin').

-behaviour(gen_server).

-include("dispatcher.hrl").

-include_lib("rabbitmq_client/include/amqp_client.hrl").

-export([start_link/0]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(conn, {
          channel    :: pid(),
          exchange   :: binary(),
          queue      :: binary(),
          route      :: binary(),
          tag        :: binary()
         }).

-record(state, {
          conf,
          conn,
          info
         }).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    process_flag(trap_exit, true),
    User = dispatcher_app:get_app_env(iface_mq_user, ?DEF_IFACE_MQ_USER),
    Password = dispatcher_app:get_app_env(iface_mq_pass, ?DEF_IFACE_MQ_PASS),
    Host = dispatcher_app:get_app_env(iface_mq_host, ?DEF_IFACE_MQ_HOST),
    Realm = list_to_binary(dispatcher_app:get_app_env(iface_mq_realm, ?DEF_IFACE_MQ_REALM)),

    ?DBG("Start Broker: ~p~n~p~n~p~n~p", [User, Password, Host, Realm]),

    Exch = <<"dispatcher.adapter">>, Queue = <<"dispatcher.main">>, RoutKey = <<"dispatcher.main">>,

    AP = #amqp_params{username = User,
                      password = Password,
                      virtual_host = Realm,
                      host = Host},

    Connection = amqp_connection:start_network(AP),
    Channel = amqp_connection:open_channel(Connection),

    amqp_channel:call(
      Channel, #'exchange.declare'{exchange    = Exch,
                                   auto_delete = true}),

    amqp_channel:call(
      Channel, #'queue.declare'{queue       = Queue,
                                auto_delete = true}),

    amqp_channel:call(
      Channel, #'queue.bind'{queue       = Queue,
                             routing_key = RoutKey,
                             exchange    = Exch}),

    Tag = amqp_channel:subscribe(
            Channel, #'basic.consume'{queue = Queue},
            self()),
    ?DBG("Tag: ~p", [Tag]),


    ?DBG("Broker started", []),
    {ok, #state{conn = #conn{channel = Channel,
                             exchange = Exch,
                             queue = Queue,
                             route = RoutKey},
                conf = #conf{user = User,
                             password = Password,
                             host = Host,
                             realm = Realm}}}.

handle_call(Request, _From, State) ->
    {reply, Request, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(#'basic.consume_ok'{consumer_tag = CTag},
            #state{conn = #conn{channel = _Channel,
                                exchange = _Exch,
                                route = _RoutKey}} = State) ->
    ?DBG("Consumer Tag: ~p", [CTag]),
    {noreply, State};
handle_info({#'basic.deliver'{consumer_tag = CTag,
                              delivery_tag = DeliveryTag,
                              exchange = Exch,
                              routing_key = RK},
             #amqp_msg{payload = Data} = Content},
            #state{conn = #conn{channel = Channel}, conf = Conf} = State) ->
    ?DBG("ConsumerTag: ~p"
         "~nDeliveryTag: ~p"
         "~nExchange: ~p"
         "~nRoutingKey: ~p"
         "~nContent: ~p"
         "~n",
         [CTag, DeliveryTag, Exch, RK, Content]),
    D = binary_to_term(Data),
    ?INFO("Data: ~p", [D]),
    case D of
        {register, UniqKey} ->
            ?DBG("Start new proc: ~p", [UniqKey]),
            dispatcher_app:start_ep_proc([{key, UniqKey},
                                          {channel, Channel},
                                          {exchange, Exch},
                                          {conf, Conf}]);
        _ ->
            ?ERR("Unknown Data: ~p", [D])
    end,
    {noreply, State};
handle_info(Info, State) ->
    ?DBG("Handle Info noreply: ~p, ~p", [Info, State]),
    {noreply, State}.

terminate(Reason, State) ->
    ?DBG("Terminate: ~p, ~p", [Reason, State]),
    ok.

code_change(OldVsn, State, Extra) ->
    ?DBG("Code Change: ~p, ~p, ~p", [OldVsn, State, Extra]),
    {ok, State}.
