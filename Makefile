CFLAGS = -O3 -ansi -pedantic -Wall -Wextra -Wno-unused-parameter -std=c++23 -fvisibility=hidden

ERTS_INCLUDE_DIR ?= $(ERL_EI_INCLUDE_DIR)
ifeq ($(ERTS_INCLUDE_DIR),)
    ERTS_INCLUDE_DIR = $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell)
endif
EXPP_INCLUDE_DIR ?= $(shell if [ -f deps/expp/expp.hpp ]; then pwd -P; elif [ -f ../expp/expp.hpp ]; then cd ../expp && pwd -P; fi)
ifeq ($(EXPP_INCLUDE_DIR),)
    $(error EXPP_INCLUDE_DIR is not set. Set it to the directory containing expp.hpp, or place expp at deps/expp or ../expp)
endif
CFLAGS += -I$(ERTS_INCLUDE_DIR) -I$(EXPP_INCLUDE_DIR)

ifneq ($(OS), Windows_NT)
    CFLAGS += -fPIC

    ifeq ($(shell uname), Darwin)
	LDFLAGS += -dynamiclib -undefined dynamic_lookup
    endif
endif

.PHONY: all imagex clean fmt

all: imagex_c

imagex_c: priv/imagex_c.so

priv/imagex_c.so: priv native/src/imagex.cpp
	$(CXX) $(CFLAGS) -shared $(LDFLAGS) -o $@ native/src/imagex.cpp -ljpeg -lpng -ljxl -ljxl_threads -lpoppler-cpp -ltiff -ltiffxx

priv:
	@mkdir -p priv

clean:
	$(RM) priv/imagex_c.so

fmt:
	find native/src -type f | xargs clang-format -i
	gleam format
