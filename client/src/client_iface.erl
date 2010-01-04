-module(client_iface).
-author('Maxim Treskin').

-behaviour(gen_server).

-include("client.hrl").

-include_lib("rabbitmq_server/include/rabbit.hrl").
-include_lib("rabbitmq_server/include/rabbit_framing.hrl").

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

    Connection = amqp_connection:start(User, Password, Host, Realm),
    Channel = lib_amqp:start_channel(Connection),

    lib_amqp:declare_exchange(Channel, Exch),   % Must be declared by dispatcher


    %% Uniq = term_to_binary({node(), make_ref()}),
    Uniq = list_to_binary(ssl_base64:encode(erlang:md5(term_to_binary(make_ref())))),
    ?DBG("Uniq: ~p", [Uniq]),
    CRoutKey = Queue = <<"client.main.", Uniq/binary>>,
    SRoutKey = <<"client.serv.", Uniq/binary>>,
    ?DBG("Queue: ~p", [Queue]),



    lib_amqp:declare_queue(Channel, Queue),
    lib_amqp:bind_queue(Channel, Exch, Queue, CRoutKey),

    Tag = lib_amqp:subscribe(Channel, Queue, self()),
    ?DBG("Tag: ~p", [Tag]),

    %% lib_amqp:bind_queue(Channel, Exch, CQueue, CRoutKey),
    %% Tag = lib_amqp:subscribe(Channel, CQueue, self()),
    %% ?DBG("Tag: ~p", [Tag]),



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
             #content{payload_fragments_rev = RevData} = Content},
            #state{conn = _Conn} = State) ->
    ?DBG("ConsumerTag: ~p"
         "~nDeliveryTag: ~p"
         "~nExchange: ~p"
         "~nRoutingKey: ~p"
         "~nContent: ~p"
         "~n",
         [CTag, DeliveryTag, Exch, RK, Content]),
    Data = iolist_to_binary(lists:reverse(RevData)),
    D = binary_to_term(Data),
    ?INFO("Data: ~p", [D]),
    {noreply, State};
handle_info({register}, #state{conn = #conn{channel = Channel,
                                            exchange = Exch,
                                            broker = BrokerRoutKey},
                              uniq = Uniq} = State) ->
    ?DBG("Registration on: ~p", [BrokerRoutKey]),
	Payload = term_to_binary({register, Uniq}),
	lib_amqp:publish(Channel, Exch, BrokerRoutKey, Payload),
    {noreply, State};
handle_info({msg, Msg}, #state{conn = #conn{channel = Channel,
                                            exchange = Exch,
                                            sroute = SRoutKey}} = State) ->
    ?DBG("Message: ~p", [Msg]),
	Payload = term_to_binary(Msg),
	lib_amqp:publish(Channel, Exch, SRoutKey, Payload),
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
