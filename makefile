.DEFAULT_GOAL: all

.PHONY: all
all:
	echo ok

.PHONY: update
update:
	./update.sh | tee package.nix
