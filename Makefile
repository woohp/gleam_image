CFLAGS = -O3 -ansi -pedantic -Wall -Wextra -Wno-unused-parameter -std=c++2b

ERLANG_PATH = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
CFLAGS += -I$(ERLANG_PATH)

ifneq ($(OS), Windows_NT)
    CFLAGS += -fPIC

    ifeq ($(shell uname), Darwin)
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
    endif
endif

.PHONY: all imagex clean fmt

all: imagex_c

imagex_c: priv/imagex_c.so

priv/imagex_c.so: native/src/imagex.cpp
	$(CXX) $(CFLAGS) -shared $(LDFLAGS) -o $@ native/src/imagex.cpp -ljpeg -lpng -ljxl -ljxl_threads -lpoppler-cpp -ltiff -ltiffxx

clean:
	$(RM) priv/imagex_c.so

fmt:
	find native/src -type f | xargs clang-format -i
	gleam format
