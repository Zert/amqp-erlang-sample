%% -*- mode: Erlang; -*-

{application, dispatcher,
 [
  {description, "Dispatcher"},
  {vsn, "1.0"},
  {id, "dispatcher"},
  {modules, [
			 dispatcher,
			 dispatcher_app,
			 dispatcher_broker,
			 dispatcher_ep
			]},
  {registered, [
				dispatcher_broker_sup,
				dispatcher_ep_sup
			   ]},
  {applications, [kernel, stdlib]},
  {mod, {dispatcher_app, []}},
  {env, []}
 ]
}.
