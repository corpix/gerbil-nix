.DEFAULT_GOAL: all

version := $(shell date +"%Y-%m-%d").$(shell git rev-list --count HEAD)

.PHONY: all
all:
	echo ok

.PHONY: tag
tag:
	git tag v$(version)

.PHONY: update
update:
	./update.sh | tee gerbil.nix
