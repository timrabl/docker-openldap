.PHONY: default build debug

BUILD_DATE := $(shell date)
_NAME := $(shell git rev-parse --show-toplevel)
BUILD_NAME := $(shell basename $(_NAME))
BUILD_VCS_REF := $(shell git rev-parse --abbrev-ref HEAD)
BUILD_VCS_URL := $(shell git remote get-url origin)

default: build

build:
	docker build -t timrabl/$(BUILD_NAME):latest \
		--build-arg BUILD_DATE="$(BUILD_DATE)" \
		--build-arg BUILD_NAME="$(BUILD_VCS_REF)" \
		--build-arg BUILD_VCS_REF="$(BUILD_VCS_REF)" \
		--build-arg BUILD_VCS_URL="$(BUILD_VCS_URL)" \
		.

debug:
	docker-compose down -v
	make
	docker-compose up -d
	docker-compose logs -f
