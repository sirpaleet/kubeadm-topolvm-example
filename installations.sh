#!/bin/bash
# This should be run first on control-plane and then on worker node vm to set up environment.

# set up environment variables to .bashrc
echo 'export PATH=/home/ubuntu/.krew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
echo 'LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' >> ~/.bashrc
echo 'LD_RUN_PATH=$LD_RUN_PATH:/usr/local/lib' >> ~/.bashrc
echo 'CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock' >> ~/.bashrc
source ~/.bashrc

# install build-essential and tar
echo "INSTALL BASICS: "
sudo apt install build-essential tar

echo "UPDATES: "
sudo apt-get update

cd
# Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# runc
sudo apt-get install runc
echo "INSTALLATION OF RUNC DONE"

# containerd
echo "DOWNLOADING CONTAINERD RELEASE 2.1.3"
wget https://github.com/containerd/containerd/releases/download/v2.1.3/containerd-2.1.3-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-2.1.3-linux-amd64.tar.gz
sudo wget -P /usr/local/lib/systemd/system/ https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mkdir -p /etc/containerd
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
echo "INSTALLATION DONE"

# CNI plugins
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz
echo "CNI PLUGINS INSTALLATION DONE, next configuration"

# kubeadm
echo "INSTALL OTHER TOOLS: "
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# there is an error here, so do a manual restart (do the steps in README for this first):
sudo systemctl restart user@1000.service

# specifically installing 1.32 for TopoLVM
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# for Kubeadm
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

sudo chmod 777 /run/containerd/containerd.sock
crictl -r unix:///run/containerd/containerd.sock

# crictl
VERSION="v1.32.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Manually do these to fix warning:
#sudo touch /etc/crictl.yaml
#sudo nano /etc/crictl.yaml
#runtime-endpoint: "unix:///run/containerd/containerd.sock"
#timeout: 0
#debug: false

# go (delete old and install)
cd
wget https://go.dev/dl/go1.24.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.4.linux-amd64.tar.gz
source ~/.bashrc

echo "INSTALL TOOLS FOR TOPOLVM: "
sudo apt-get install -y lvm2 xfsprogs thin-provisioning-tools
sudo apt-get update

# cloning topolvm
git clone git@github.com:topolvm/topolvm.git
cd ~/topolvm
git remote rename origin upstream
git remote add origin git@github.com:Nordix/topolvm.git
git remote -v
# For TopoLVM:
echo 'export SKIP_TESTS_USING_ROOT=1' >> ~/.bashrc
source ~/.bashrc

# moving this directory
sudo mv ../kubeadm-topolvm-example ~/topolvm/kubeadm-topolvm-example
cd ~/topolvm/kubeadm-topolvm-example
