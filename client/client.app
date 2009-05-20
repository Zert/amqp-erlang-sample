%% -*- mode: Erlang; -*-

{application, client,
 [
  {description, "Dispatcher"},
  {vsn, "1.0"},
  {id, "client"},
  {modules, [
			 client,
			 client_app,
			 client_iface,
			 client_ep
			]},
  {registered, [
				client_iface_sup,
				client_ep_sup
			   ]},
  {applications, [kernel, stdlib]},
  {mod, {client_app, []}},
  {env, []}
 ]
}.
