# -*- mode: Python -*-
# --------------------------
# Extensions and Configuration
# Place this in the root of TopoLVM directory if used
# --------------------------
# Load extensions
load('ext://helm_resource', 'helm_resource', 'helm_repo')
# Allow running against the specified k8s context
allow_k8s_contexts('kubernetes-admin@kubernetes')
# Use anonymous, ephemeral image registry
default_registry('ttl.sh')
# Tilt settings
update_settings(
    max_parallel_updates=3,
    k8s_upsert_timeout_secs=300,
    suppress_unused_image_warnings=None
)
# --------------------------
# Build and Image Definitions
# --------------------------
# Build commands
MAKE_SETUP = 'export PATH=$PATH:/usr/local/go/bin && export PATH=$PATH:/home/ubuntu/go/bin && make setup -S'
MAKE_BUILD = 'make build'
# Build the binary
local_resource(
    'binary-build',
    MAKE_SETUP,
    MAKE_BUILD,
)

# Container image name
IMAGE = "ttl.sh/topolvm-local"
# Build the Docker image
docker_build(
    IMAGE,
    '.',
    dockerfile='./Dockerfile'
)
# --------------------------
# Helm Setup and Deployment
# --------------------------
# Add and update Helm repo
local("export PATH=$PATH:/usr/local/go/bin && export PATH=$PATH:/home/ubuntu/go/bin")
local("echo $PATH")
local("helm repo add jetstack https://charts.jetstack.io")
local("helm repo update")
# local("kubectl create namespace topolvm-system")
# deploy_cert_manager(version=settings.get("cert_manager_version"))
local("kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.crds.yaml")
local("kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.1/cert-manager.yaml")
local("kubectl label namespace topolvm-system topolvm.io/webhook=ignore")
local("kubectl label namespace kube-system topolvm.io/webhook=ignore")
local("kubectl kustomize https://github.com/kubernetes-csi/external-snapshotter/client/config/crd | kubectl apply -f -")
# Build chart dependencies
local("helm dependency build ./charts/topolvm/")
# Deploy Helm chart
helm_resource(
    'topolvm',
    './charts/topolvm/',
    namespace='topolvm-system',
    image_deps=[IMAGE],
    image_keys=[('image.repository', 'image.tag')],
    flags=['--values=./kubeadm-topolvm-example/values.yaml'],
    resource_deps=['binary-build']
)
