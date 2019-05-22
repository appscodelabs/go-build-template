SHELL=/bin/bash -o pipefail

# The binary to build (just the basename).
BIN := myapp
COMPRESS ?=no

# Where to push the docker image.
REGISTRY ?= tigerworks

# This version-strategy uses git tags to set the version string
VERSION := $(shell git describe --tags --always --dirty)
#
# This version-strategy uses a manual value to set the version string
#VERSION := 1.2.3

###
### These variables should not need tweaking.
###

SRC_DIRS := cmd pkg # directories which hold app source (not vendored)

DOCKER_PLATFORMS := linux/amd64 linux/arm linux/arm64
BIN_PLATFORMS    := $(DOCKER_PLATFORMS) windows/amd64 darwin/amd64

# Used internally.  Users should pass GOOS and/or GOARCH.
OS := $(if $(GOOS),$(GOOS),$(shell go env GOOS))
ARCH := $(if $(GOARCH),$(GOARCH),$(shell go env GOARCH))

BASEIMAGE ?= gcr.io/distroless/static

IMAGE := $(REGISTRY)/$(BIN)
TAG := $(VERSION)_$(OS)_$(ARCH)

BUILD_IMAGE ?= appscode/golang-dev:1.12.5-alpine

# If you want to build all binaries, see the 'all-build' rule.
# If you want to build all containers, see the 'all-container' rule.
# If you want to build AND push all containers, see the 'all-push' rule.
all: gen fmt build

# For the following OS/ARCH expansions, we transform OS/ARCH into OS_ARCH
# because make pattern rules don't match with embedded '/' characters.

build-%:
	@$(MAKE) build                        \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

container-%:
	@$(MAKE) container                    \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

push-%:
	@$(MAKE) push                         \
	    --no-print-directory              \
	    GOOS=$(firstword $(subst _, ,$*)) \
	    GOARCH=$(lastword $(subst _, ,$*))

all-build: $(addprefix build-, $(subst /,_, $(BIN_PLATFORMS)))

all-container: $(addprefix container-, $(subst /,_, $(DOCKER_PLATFORMS)))

all-push: $(addprefix push-, $(subst /,_, $(DOCKER_PLATFORMS)))

OUTBIN = bin/$(OS)_$(ARCH)/$(BIN)
ifeq ($(OS),windows)
  OUTBIN = bin/$(OS)_$(ARCH)/$(BIN).exe
endif

build: $(OUTBIN)

# Directories that we need created to build/test.
BUILD_DIRS := bin/$(OS)_$(ARCH)     \
              .go/bin/$(OS)_$(ARCH) \
              .go/cache

# The following structure defeats Go's (intentional) behavior to always touch
# result files, even if they have not changed.  This will still run `go` but
# will not trigger further work if nothing has actually changed.

$(OUTBIN): .go/$(OUTBIN).stamp
	@true

# This will build the binary under ./.go and update the real binary iff needed.
.PHONY: .go/$(OUTBIN).stamp
.go/$(OUTBIN).stamp: $(BUILD_DIRS)
	@echo "making $(OUTBIN)"
	@docker run                                                 \
	    -i                                                      \
	    --rm                                                    \
	    -u $$(id -u):$$(id -g)                                  \
	    -v $$(pwd):/src                                         \
	    -w /src                                                 \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin                \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin/$(OS)_$(ARCH)  \
	    -v $$(pwd)/.go/cache:/.cache                            \
	    --env HTTP_PROXY=$(HTTP_PROXY)                          \
	    --env HTTPS_PROXY=$(HTTPS_PROXY)                        \
	    $(BUILD_IMAGE)                                          \
	    /bin/bash -c "                                          \
	        ARCH=$(ARCH)                                        \
	        OS=$(OS)                                            \
	        VERSION=$(VERSION)                                  \
	        ./hack/build.sh                                     \
	    "
	@if [ $(COMPRESS) = yes ] && [ $(OS) != windows ]; then \
		echo "compressing $(OUTBIN)";                       \
		upx --brute .go/$(OUTBIN);                          \
	fi
	@if ! cmp -s .go/$(OUTBIN) $(OUTBIN); then \
	    mv .go/$(OUTBIN) $(OUTBIN);            \
	    date >$@;                              \
	fi

# Example: make shell CMD="-c 'date > datefile'"
shell: $(BUILD_DIRS)
	@echo "launching a shell in the containerized build environment"
	@docker run                                                 \
	    -ti                                                     \
	    --rm                                                    \
	    -u $$(id -u):$$(id -g)                                  \
	    -v $$(pwd):/src                                         \
	    -w /src                                                 \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin                \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin/$(OS)_$(ARCH)  \
	    -v $$(pwd)/.go/cache:/.cache                            \
	    --env HTTP_PROXY=$(HTTP_PROXY)                          \
	    --env HTTPS_PROXY=$(HTTPS_PROXY)                        \
	    $(BUILD_IMAGE)                                          \
	    /bin/bash $(CMD)

# Used to track state in hidden files.
DOTFILE_IMAGE = $(subst /,_,$(IMAGE))-$(TAG)

container: bin/.container-$(DOTFILE_IMAGE) say_container_name
bin/.container-$(DOTFILE_IMAGE): bin/$(OS)_$(ARCH)/$(BIN) Dockerfile.in
	@sed                                 \
	    -e 's|{ARG_BIN}|$(BIN)|g'        \
	    -e 's|{ARG_ARCH}|$(ARCH)|g'      \
	    -e 's|{ARG_OS}|$(OS)|g'          \
	    -e 's|{ARG_FROM}|$(BASEIMAGE)|g' \
	    Dockerfile.in > bin/.dockerfile-$(OS)_$(ARCH)
	@docker build -t $(IMAGE):$(TAG) -f bin/.dockerfile-$(OS)_$(ARCH) .
	@docker images -q $(IMAGE):$(TAG) > $@

say_container_name:
	@echo "container: $(IMAGE):$(TAG)"

push: bin/.push-$(DOTFILE_IMAGE) say_push_name
bin/.push-$(DOTFILE_IMAGE): bin/.container-$(DOTFILE_IMAGE)
	@docker push $(IMAGE):$(TAG)

say_push_name:
	@echo "pushed: $(IMAGE):$(TAG)"

version:
	@echo $(VERSION)

test: $(BUILD_DIRS)
	@docker run                                                 \
	    -i                                                      \
	    --rm                                                    \
	    -u $$(id -u):$$(id -g)                                  \
	    -v $$(pwd):/src                                         \
	    -w /src                                                 \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin                \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin/$(OS)_$(ARCH)  \
	    -v $$(pwd)/.go/cache:/.cache                            \
	    --env HTTP_PROXY=$(HTTP_PROXY)                          \
	    --env HTTPS_PROXY=$(HTTPS_PROXY)                        \
	    $(BUILD_IMAGE)                                          \
	    /bin/bash -c "                                            \
	        ARCH=$(ARCH)                                        \
	        OS=$(OS)                                            \
	        VERSION=$(VERSION)                                  \
	        ./hack/test.sh $(SRC_DIRS)                          \
	    "

$(BUILD_DIRS):
	@mkdir -p $@

.PHONY: clean
clean:
	rm -rf .go bin


#################################################################

ADDTL_LINTERS  := goconst,gofmt,goimports,unparam

.PHONY: lint
lint: $(BUILD_DIRS)
	@echo "running linter"
	@docker run                                                 \
	    -i                                                      \
	    --rm                                                    \
	    -u $$(id -u):$$(id -g)                                  \
	    -v $$(pwd):/src                                         \
	    -w /src                                                 \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin                \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin/$(OS)_$(ARCH)  \
	    -v $$(pwd)/.go/cache:/.cache                            \
	    --env HTTP_PROXY=$(HTTP_PROXY)                          \
	    --env HTTPS_PROXY=$(HTTPS_PROXY)                        \
	    $(BUILD_IMAGE)                                         \
	    golangci-lint run --enable $(ADDTL_LINTERS)

################################################################


.PHONY: ci
ci: lint test build #cover

gen:
	@true

fmt: $(BUILD_DIRS)
	@docker run                                                 \
	    -i                                                      \
	    --rm                                                    \
	    -u $$(id -u):$$(id -g)                                  \
	    -v $$(pwd):/src                                         \
	    -w /src                                                 \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin                \
	    -v $$(pwd)/.go/bin/$(OS)_$(ARCH):/go/bin/$(OS)_$(ARCH)  \
	    -v $$(pwd)/.go/cache:/.cache                            \
	    --env HTTP_PROXY=$(HTTP_PROXY)                          \
	    --env HTTPS_PROXY=$(HTTPS_PROXY)                        \
	    $(BUILD_IMAGE)                                          \
	    ./hack/fmt.sh $(SRC_DIRS)
