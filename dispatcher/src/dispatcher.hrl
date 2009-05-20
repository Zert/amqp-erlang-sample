-define(DBG(F, A), io:format("DBG: ~w:~b: " ++ F ++ "~n", [?MODULE, ?LINE] ++ A)).
-define(ERR(F, A), io:format("***ERR***: ~w:~b: " ++ F ++ "~n", [?MODULE, ?LINE] ++ A)).
-define(INFO(F, A), io:format("===INFO===: ~w:~b: " ++ F ++ "~n", [?MODULE, ?LINE] ++ A)).

-record(conf, {
          user       :: string(),
          password   :: string(),
          host       :: string(),
          realm      :: string()
         }).


-define(DEF_IFACE_MQ_USER, "dispatcher").
-define(DEF_IFACE_MQ_PASS, "dispatcher").
-define(DEF_IFACE_MQ_HOST, "localhost").
-define(DEF_IFACE_MQ_REALM, "/").
