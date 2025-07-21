include ../versions.mk

SUDO := sudo
CURL := curl -sSLf
HOSTNAME := $(shell hostname)
BINDIR := $(shell pwd)/bin
TMPDIR := /tmp/$(HOSTNAME)
HELM := $(BINDIR)/helm
KUBECTL := kubectl
KUBEADM := kubeadm
KUBELET := kubelet
# This should be edited to match the installed version
KUBERNETES_VERSION := 1.32.7

GO_FILES := $(shell find .. -prune -o -path ../test/e2e -prune -o -name '*.go' -print)
BACKING_STORE := ./build

HELM_VALUES_FILE := values.yaml
LOGICALVOLUME_GK_NAME := logicalvolume.topolvm.io
DOMAIN_NAME := topolvm.io

.PHONY: setup
setup:
	mkdir -p build
	./installations.sh
	

.PHONY: clean
clean: stop-lvmd
	rm -rf build/ $(TMPDIR)

.PHONY: distclean
distclean: clean
	rm -rf bin/

# Moves sock from run to tmp directory
$(TMPDIR)/lvmd/lvmd.yaml: ../deploy/lvmd-config/lvmd.yaml
	mkdir -p $(TMPDIR)/lvmd
	sed -e 's=/run/topolvm/lvmd.sock=$(TMPDIR)/lvmd/lvmd.sock=; s=spare-gb: 10=spare-gb: 1=' $< > $@

# Makes config for kubeadm init
# ADVERTISE_ADDRESS is the IP of the control-plane node
.PHONY: init-config
init-config:
	export HOSTNAME=$(HOSTNAME); \
	export ADVERTISE_ADDRESS=$(ADVERTISE_ADDRESS); \
	export KUBERNETES_VERSION=$(KUBERNETES_VERSION); \
	envsubst < initconfig-template.yaml  > initconfig.yaml; \

# Creates cluster with control-plane node
# ( $(MAKE) init-config ADVERTISE_ADDRESS=<IP of control-plane node> )
# ( $(SUDO) $(KUBEADM) init --config=./initconfig.yaml )

.PHONY: create-cluster
create-cluster:
	./configure-containerd.sh
	$(SUDO) $(KUBEADM) init --kubernetes-version=$(KUBERNETES_VERSION) --cri-socket=unix:///run/containerd/containerd.sock  --pod-network-cidr=192.168.0.0/16 --upload-certs; \
	mkdir -p ${HOME}/.kube; \
	$(SUDO) cp -i /etc/kubernetes/admin.conf ${HOME}/.kube/config; \
	$(SUDO) chown $$(id -u):$$(id -g) ${HOME}/.kube/config; \
	$(KUBECTL) create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml
	$(KUBECTL) create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml
	$(KUBECTL) create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# Setting up cluster with TopoLVM and one control plane node
.PHONY: run
run:
	$(MAKE) create-cluster
	$(KUBECTL) apply -f https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.crds.yaml
	$(KUBECTL) create namespace topolvm-system
	$(KUBECTL) label namespace topolvm-system $(DOMAIN_NAME)/webhook=ignore
	$(KUBECTL) label namespace kube-system $(DOMAIN_NAME)/webhook=ignore
	$(HELM) repo add topolvm https://topolvm.github.io/topolvm
	$(HELM) repo add jetstack https://charts.jetstack.io
	$(HELM) repo update
	$(HELM) dependency build ../charts/topolvm/
	$(KUBECTL) create configmap lvmd-config \
	  --from-file=lvmd.yaml=$(shell pwd)/../deploy/lvmd-config/lvmd.yaml \
	  -n topolvm-system

# Called after join
.PHONY: finish-run
finish-run:
	$(HELM) install --namespace=topolvm-system topolvm ../charts/topolvm/ -f $(HELM_VALUES_FILE) --set lvmd.enabled=true --set lvmd.configMap=lvmd-config
	$(KUBECTL) wait --for=condition=available --timeout=120s -n topolvm-system deployments/topolvm-controller
	$(KUBECTL) wait --for=condition=ready --timeout=120s -n topolvm-system -l="app.kubernetes.io/component=controller,app.kubernetes.io/name=topolvm" pod
	$(KUBECTL) wait --for=condition=ready --timeout=120s -n topolvm-system certificate/topolvm-mutatingwebhook

# Creates worker node with pods and pvcs
# Variables should be assigned with values (IP, TOKEN and HASH) from kubeadm init output
.PHONY: create-worker
create-worker:
	$(SUDO) rm -rf /run/topolvm
	./configure-containerd.sh
	$(SUDO) ln -s $(TMPDIR)/lvmd /run/topolvm
	$(SUDO) $(KUBEADM) join $(IP) --token $(TOKEN) --discovery-token-ca-cert-hash $(HASH)

# Applies pods and pvcs to worker node
# Specify WORKERNAME
.PHONY: complete-worker
complete-worker:
	$(KUBECTL) label node $(WORKERNAME) node-role.kubernetes.io/worker=worker
	timeout 120 sh -c "until $(KUBECTL) apply -f podpvc.yaml; do sleep 10; done"
	$(KUBECTL) wait --for=condition=ready --timeout=120s -n default pod -l app=kubeadm-topolvm-example
	[ $$($(KUBECTL) get --no-headers=true $(LOGICALVOLUME_GK_NAME) | wc -l) -ne 0 ]

# Unmounts tmpdir directories
.PHONY: unmount-tmpdir
unmount-tmpdir:
	for d in $$($(SUDO) find $(TMPDIR) -type d); do \
		if $(SUDO) mountpoint -q $$d; then \
			$(SUDO) umount $$d; \
		fi; \
	done

# Shuts down control-plane and cluster
.PHONY: shutdown-cluster
shutdown-cluster:
	$(SUDO) $(KUBEADM) reset --force --cri-socket=unix:///run/containerd/containerd.sock; \
	$(MAKE) unmount-tmpdir; \

# Deletes worker node from control-plane's side (from cluster) (1.)
# Specify WORKERNAME
.PHONY: remove-worker
remove-worker:
	$(KUBECTL) delete -f ./podpvc.yaml
	$(KUBECTL) cordon $(WORKERNAME)
	$(KUBECTL) delete node $(WORKERNAME) --timeout=120s
	watch $(KUBECTL) get pods --all-namespaces --output=wide

# OR (this can be used instead, in case you wish to re-use the node)
# Specify WORKERNAME
.PHONY: drain-worker
drain-worker:
	$(KUBECTL) drain $(WORKERNAME) --delete-emptydir-data --force  --ignore-daemonsets --timeout=180s

# Shuts down worker node on the worker node's side (2.)
.PHONY: shutdown-worker
shutdown-worker:
	$(SUDO) $(KUBEADM) reset --force --cri-socket=unix:///run/containerd/containerd.sock
	$(MAKE) unmount-tmpdir
	$(SUDO) rm /run/topolvm

# Separating lvmd start commands because of possible differences later (memory, directories etc.)
.PHONY: start-lvmd-control-plane
start-lvmd-control-plane: $(TMPDIR)/lvmd/lvmd.yaml
	go build -o build/lvmd ../cmd/lvmd
	if [ -f $(BACKING_STORE)/backing_store ]; then $(MAKE) stop-lvmd; fi; \
	mkdir -p $(TMPDIR)/lvmd; \
	truncate --size=20G $(BACKING_STORE)/backing_store; \
	$(SUDO) losetup -f $(BACKING_STORE)/backing_store; \
	$(SUDO) vgcreate -f -y myvg1 $$($(SUDO) losetup -j $(BACKING_STORE)/backing_store | cut -d: -f1); \
	$(SUDO) lvcreate -T myvg1/thinpool -L 12G; \
	$(SUDO) systemd-run --unit=lvmd.service $(shell pwd)/build/lvmd --config=$(TMPDIR)/lvmd/lvmd.yaml; \

.PHONY: start-lvmd-worker
start-lvmd-worker: $(TMPDIR)/lvmd/lvmd.yaml
	go build -o build/lvmd ../cmd/lvmd
	if [ -f $(BACKING_STORE)/backing_store ]; then $(MAKE) stop-lvmd; fi; \
	mkdir -p $(TMPDIR)/lvmd; \
	truncate --size=20G $(BACKING_STORE)/backing_store; \
	$(SUDO) losetup -f $(BACKING_STORE)/backing_store; \
	$(SUDO) vgcreate -f -y myvg1 $$($(SUDO) losetup -j $(BACKING_STORE)/backing_store | cut -d: -f1); \
	$(SUDO) lvcreate -T myvg1/thinpool -L 12G; \
	$(SUDO) systemd-run --unit=lvmd.service $(shell pwd)/build/lvmd --config=$(TMPDIR)/lvmd/lvmd.yaml; \

.PHONY: stop-lvmd
stop-lvmd:
	if systemctl is-active -q lvmd.service; then $(SUDO) systemctl stop lvmd.service; fi; \
	if [ -f $(BACKING_STORE)/backing_store ]; then \
		$(SUDO) vgremove -ffy myvg1; \
		$(SUDO) pvremove -ffy $$($(SUDO) losetup -j $(BACKING_STORE)/backing_store | cut -d: -f1); \
		$(SUDO) losetup -d $$($(SUDO) losetup -j $(BACKING_STORE)/backing_store | cut -d: -f1); \
		rm -f $(BACKING_STORE)/backing_store; \
	fi
