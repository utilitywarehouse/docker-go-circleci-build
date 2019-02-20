
ifeq ("$(wildcard project)","")
$(error project directory doesn't exist)
endif

ifneq ("$(wildcard project/app.mk)","")
	include project/app.mk
endif


# --------------------------------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------------------------------

ifndef APP_NAME
$(error APP_NAME is not set, create a .mk file and set it)
endif

ifndef APP_DESCRIPTION
$(error APP_DESCRIPTION is not set, create a .mk file and set it)
endif

GIT_SUMMARY := $(shell cd project && git describe --tags --dirty --always)
GIT_BRANCH := $(shell cd project && git rev-parse --abbrev-ref HEAD)
BUILD_STAMP := $(shell date -u '+%Y-%m-%dT%H:%M:%S%z')

LDFLAGS := -ldflags '-s \
	-X "github.com/utilitywarehouse/partner-pkg/meta.ApplicationName=$(APP_NAME)" \
	-X "github.com/utilitywarehouse/partner-pkg/meta.ApplicationDescription=$(APP_DESCRIPTION)" \
	-X "github.com/utilitywarehouse/partner-pkg/meta.GitSummary=$(GIT_SUMMARY)" \
	-X "github.com/utilitywarehouse/partner-pkg/meta.GitBranch=$(GIT_BRANCH)" \
	-X "github.com/utilitywarehouse/partner-pkg/meta.BuildStamp=$(BUILD_STAMP)"'

# --------------------------------------------------------------------------------------------------
# Setup Tasks
# --------------------------------------------------------------------------------------------------

install-ci: ## install dependencies and redact github token
	cd project && go get -d -v ./... 2>&1 | sed -e "s/[[:alnum:]]*:x-oauth-basic/redacted/"

test-ci: ## run tests on package and all subpackages
	cd project && go test $(LDFLAGS) -v -race -tags integration ./...

lint-ci: ## run the linter
	cd project && golangci-lint run --deadline=2m

# --------------------------------------------------------------------------------------------------
# Build Tasks
# --------------------------------------------------------------------------------------------------

build-app-ci:
ifneq ("$(wildcard project/main.go)","")
	cd project && CGO_ENABLED=0 go build $(LDFLAGS) -o bin/$(APP_NAME) -a .
endif

cmd_sources = $(dir $(wildcard ./project/cmd/*/main.go))
cmds = $(foreach source,$(cmd_sources),$(patsubst %/,%,$(subst ./project/cmd,./bin,$(source))))

define go-build
	cd ./$< && CGO_ENABLED=0 go build $(LDFLAGS) -o ./../../../$@ -a .
endef

./bin/%: ./project/cmd/% ## build individual command
	$(go-build)

build-commands-ci: $(cmds) ## build all commands

build-all-ci: build-app-ci build-commands-ci

# --------------------------------------------------------------------------------------------------
# Fallback
# --------------------------------------------------------------------------------------------------

%: ## fallback to the project makefile
	cd project && $(MAKE) -f Makefile $@
