.DEFAULT_GOAL: all

version := $(shell date +"%Y-%m-%d").$(shell git rev-list --count HEAD)

.PHONY: all
all: build

.PHONY: build
build:
	nix build --print-out-paths -L .#packages.x86_64-linux.gerbil-static

.PHONY: tag
tag:
	git tag v$(version)

.PHONY: update
update:
	./update.sh | tee gerbil.nix
