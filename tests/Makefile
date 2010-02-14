CFLAGS ?= -g -O2 -fomit-frame-pointer -Wformat -pedantic
CFLAGS += --std=c99

BASH_TESTS = 
ZSH_TESTS = 
ANY_TESTS = sleeps

.PHONY: clean all $(BASH_TEST) $(ZSH_TESTS) $(ANY_TESTS)

all: $(ANY_TESTS) $(BASH_TESTS) $(ZSH_TESTS)

clean:
	rm -f bash_found zsh_found any_found both_found

bash_found:
	-which bash && touch bash_found

zsh_found:
	-which zsh && touch zsh_found

any_found: zsh_found bash_found
	[[ -f bash_found && -f zsh_found ]] && touch both_found
	[[ -f bash_found || -f zsh_found ]] && touch any_found

$(ANY_TESTS): any_found
	if [[ -f both_found ]] ; then \
		bash $@ && zsh $@; \
	elif [[ -f bash_found ]] ; then \
		bash $@; \
	elif [[ -f zsh_found ]] ; then \
		zsh $@; \
	else \
	echo "Something's wrong"; \
		false; \
	fi

$(BASH_TESTS): bash_found
	bash $@

$(ZSH_TESTS): zsh_found
	zsh $@

# For emacs' flymake-mode
.PHONY: check-syntax
check-syntax:
	gcc -Wall -Wextra -Wundef -Wshadow -Wunsafe-loop-optimizations -Wsign-compare -fsyntax-only ${CHK_SOURCES}