-module(client_iface).
-author('Maxim Treskin').

-behaviour(gen_server).

-include("client.hrl").

-include_lib("amqp_client/include/amqp_client.hrl").

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
          croute     :: binary(),
          sroute     :: binary(),
          broker     :: binary(),
          tag        :: binary()
         }).

-record(state, {
          conn,
          info,
          uniq
         }).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_) ->
    process_flag(trap_exit, true),
    User = client_app:get_app_env(iface_mq_user, ?DEF_IFACE_MQ_USER),
    Password = client_app:get_app_env(iface_mq_pass, ?DEF_IFACE_MQ_PASS),
    Host = client_app:get_app_env(iface_mq_host, ?DEF_IFACE_MQ_HOST),
    Realm = list_to_binary(client_app:get_app_env(iface_mq_realm, ?DEF_IFACE_MQ_REALM)),

    ?DBG("Start Interface: ~p~n~p~n~p~n~p", [User, Password, Host, Realm]),

    Exch = <<"dispatcher.adapter">>,
    BrokerRoutKey = <<"dispatcher.main">>,

    AP = #amqp_params{username = User,
                      password = Password,
                      virtual_host = Realm,
                      host = Host},

    Connection = amqp_connection:start_network(AP),
    Channel = amqp_connection:open_channel(Connection),

    amqp_channel:call(
      Channel, #'exchange.declare'{exchange    = Exch,
                                   auto_delete = true}),

    Uniq = base64:encode(erlang:md5(term_to_binary(make_ref()))),
    ?DBG("Uniq: ~p", [Uniq]),
    CRoutKey = Queue = <<"client.main.", Uniq/binary>>,
    SRoutKey = <<"client.serv.", Uniq/binary>>,
    ?DBG("Queue: ~p", [Queue]),

    amqp_channel:call(
      Channel, #'queue.declare'{queue       = Queue,
                                auto_delete = true}),

    amqp_channel:call(
      Channel, #'queue.bind'{queue       = Queue,
                             routing_key = CRoutKey,
                             exchange    = Exch}),

    Tag = amqp_channel:subscribe(
            Channel, #'basic.consume'{queue = Queue},
            self()),
    ?DBG("Tag: ~p", [Tag]),

    ?DBG("Client iface started", []),
    self() ! {register},
    {ok, #state{conn = #conn{channel = Channel,
                             exchange = Exch,
                             queue = Queue,
                             croute = CRoutKey,
                             sroute = SRoutKey,
                             broker = BrokerRoutKey},
                uniq = Uniq}}.

handle_call(Request, _From, State) ->
    {reply, Request, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.


handle_info(#'basic.consume_ok'{consumer_tag = CTag},
            #state{} = State) ->
    ?DBG("Consumer Tag: ~p", [CTag]),
    {noreply, State};
handle_info({#'basic.deliver'{consumer_tag = CTag,
                              delivery_tag = DeliveryTag,
                              exchange = Exch,
                              routing_key = RK},
             #amqp_msg{payload = Data} = Content},
            #state{conn = _Conn} = State) ->
    ?DBG("ConsumerTag: ~p"
         "~nDeliveryTag: ~p"
         "~nExchange: ~p"
         "~nRoutingKey: ~p"
         "~nContent: ~p"
         "~n",
         [CTag, DeliveryTag, Exch, RK, Content]),
    D = binary_to_term(Data),
    ?INFO("Data: ~p", [D]),
    {noreply, State};
handle_info({register}, #state{conn = #conn{channel = Channel,
                                            exchange = Exch,
                                            broker = BrokerRoutKey},
                               uniq = Uniq} = State) ->
    ?DBG("Registration on: ~p", [BrokerRoutKey]),
	Payload = term_to_binary({register, Uniq}),
    amqp_channel:call(Channel,
                      #'basic.publish'{exchange    = Exch,
                                       routing_key = BrokerRoutKey},
                      #amqp_msg{props   = #'P_basic'{},
                                payload = Payload}),
    {noreply, State};
handle_info({msg, Msg}, #state{conn = #conn{channel = Channel,
                                            exchange = Exch,
                                            sroute = SRoutKey}} = State) ->
    ?DBG("Message: ~p", [Msg]),
	Payload = term_to_binary(Msg),
    amqp_channel:call(Channel,
                      #'basic.publish'{exchange    = Exch,
                                       routing_key = SRoutKey},
                      #amqp_msg{props   = #'P_basic'{},
                                payload = Payload}),
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
