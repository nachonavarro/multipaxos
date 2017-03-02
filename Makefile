
.SUFFIXES:	.erl .beam

MODULES 	= system server scout replica leader database commander client acceptor
SYSTEM 		= system
ERLC		= erlc -o ebin

ebin/%.beam:	%.erl
	$(ERLC) $<

all:	ebin ${MODULES:%=ebin/%.beam}

ebin:
	mkdir ebin

.PHONY:	clean
clean:
	rm -f ebin/* erl_crash.dump

L_ERL	= erl -noshell -pa ebin -setcookie pass -run

run:	all
	$(L_ERL) $(SYSTEM) start





 