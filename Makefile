SHELL=/bin/bash

# Run `make schema` when updating this version and commit the created files.
# TODO(lyarwood) - Host the expanded JSON schema elsewhere under the kubevirt namespace
export KUBEVIRT_VERSION = main

# Use the COMMON_INSTANCETYPES_CRI env variable to control if the following targets are executed within a container.
# Supported runtimes are docker and podman. By default targets run directly on the host.
export COMMON_INSTANCETYPES_IMAGE = quay.io/kubevirtci/common-instancetypes-builder
export COMMON_INSTANCETYPES_IMAGE_TAG = v20231124-0bd5b70

# Packages of golang tools vendored in ./tools
# Version to install is defined in ./tools/go.mod
KUSTOMIZE_PACKAGE ?= sigs.k8s.io/kustomize/kustomize/v5
KUBECONFORM_PACKAGE ?= github.com/yannh/kubeconform/cmd/kubeconform
YQ_PACKAGE ?= github.com/mikefarah/yq/v4

.PHONY: all
all: lint validate readme test

.PHONY: build_image
build_image:
	scripts/build_image.sh

.PHONY: push_image
push_image:
	scripts/push_image.sh

.PHONY: lint
lint: generate
	scripts/cri.sh "scripts/lint.sh"

.PHONY: generate
generate: kustomize yq
	scripts/generate.sh

.PHONY: validate
validate: generate schema kubeconform
	scripts/validate.sh

.PHONY: schema
schema:
	scripts/cri.sh "scripts/schema.sh"

.PHONY: readme
readme: generate
	scripts/readme.sh

.PHONY: cluster-up
cluster-up:
	scripts/kubevirtci.sh up

.PHONY: cluster-down
cluster-down:
	scripts/kubevirtci.sh down

.PHONY: cluster-sync
cluster-sync: kustomize
	scripts/kubevirtci.sh sync

.PHONY: cluster-functest
cluster-functest:
	cd tests && KUBECONFIG=$$(../scripts/kubevirtci.sh kubeconfig) go test -v -timeout 0 ./functests/...

.PHONY: kubevirt-up
kubevirt-up:
	scripts/kubevirt.sh up

.PHONY: kubevirt-down
kubevirt-down:
	scripts/kubevirt.sh down

.PHONY: kubevirt-sync
kubevirt-sync: kustomize
	scripts/kubevirt.sh sync

.PHONY: kubevirt-functest
kubevirt-functest:
	cd tests && KUBECONFIG=$$(../scripts/kubevirt.sh kubeconfig) go test -v -timeout 0 ./functests/...

.PHONY: test
test: generate
	cd tests && go test -v -timeout 0 ./unittests/...

.PHONY: clean
clean:
	rm -rf _bin _build _cluster-up _kubevirt _schemas

# Location to install local binaries to
LOCALBIN ?= $(PWD)/_bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)
export PATH := $(LOCALBIN):$(PATH)

KUSTOMIZE ?= $(LOCALBIN)/kustomize
kustomize: $(KUSTOMIZE)
$(KUSTOMIZE): $(LOCALBIN)
	cd tools && GOBIN=$(LOCALBIN) go install $(KUSTOMIZE_PACKAGE)

KUBECONFORM ?= $(LOCALBIN)/kubeconform
kubeconform: $(KUBECONFORM)
$(KUBECONFORM): $(LOCALBIN)
	cd tools && GOBIN=$(LOCALBIN) go install $(KUBECONFORM_PACKAGE)

YQ ?= $(LOCALBIN)/yq
yq: $(YQ)
$(YQ): $(LOCALBIN)
	cd tools && GOBIN=$(LOCALBIN) go install $(YQ_PACKAGE)
