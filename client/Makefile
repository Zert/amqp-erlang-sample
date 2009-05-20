ERL	= erl
RM	= rm -rf

BEAMDIR = ebin
SRCDIR  = src

APPNAME=client
APP_VSN=git
DOC_OPTS={def,{vsn,\"$(APP_VSN)\"}}

ERLFLAGS	= -pa ${BEAMDIR}

all: compile-beam TAGS

compile-beam:
	${ERL} ${ERLFLAGS} -make

clean:
	${RM} ${BEAMDIR}/*.beam erl_crash.dump ${SRCDIR}/*~ *~ TAGS doc/*

docs:
	${ERL} -noshell -eval "edoc:application($(APPNAME), \".\", [$(DOC_OPTS)])" -s init stop

dialyzer:
	dialyzer -Wno_match -c ${BEAMDIR}/*.beam

dialyzer-src:
	dialyzer --src ${INCLUDES} -Wno_match -c ${SRCDIR}/*.erl

TAGS:
	etags ${SRCDIR}/*.erl
