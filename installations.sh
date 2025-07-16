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
sudo apt install build-essential tar

cd
sudo apt-get update

# Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Docker
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world

# Installing containerd and related tools (does not work standalone, needs edit but is udes instead of docker installation)
#cd
#echo "DOWNLOADING CONTAINERD RELEASE 2.1.3"
#wget https://github.com/containerd/containerd/releases/download/v2.1.3/containerd-2.1.3-linux-amd64.tar.gz
#sudo tar Cxzvf /usr/local containerd-2.1.3-linux-amd64.tar.gz
#sudo wget -P /usr/local/lib/systemd/system/ https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
#sudo mkdir -p /etc/containerd
#containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
#sudo systemctl daemon-reload
#sudo systemctl enable --now containerd
#echo "INSTALLATION DONE, next installin runc"

#sudo mkdir -p /usr/local/sbin/runc
#sudo wget -O ~/runc.amd64 https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
#sudo install -m 755 runc.amd64 /usr/local/sbin/runc
#echo "INSTALLATION DONE, next installing cni plugins"

# CNI plugins
#sudo mkdir -p /opt/cni/bin
#wget https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
#sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.7.1.tgz
#echo "CNI PLUGINS INSTALLATION DONE, next configuration"


# configuring containerd
# Works for containerd versions 1.x
sudo modprobe br_netfilter
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.bridge.bridge-nf-call-iptables=1
sudo sysctl -w net.bridge.bridge-nf-call-ip6tables=1
sudo sysctl --system

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
containerd config default > /etc/containerd/config.toml
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's#sandbox_image = "registry.k8s.io/pause:3.8"#sandbox_image = "registry.k8s.io/pause:3.10"#' /etc/containerd/config.toml
# Change these manually in v 2.x containerd: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd 
sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl enable --now containerd


# kubeadm
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# specifically installing 1.32.2 for TopoLVM
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y --allow-downgrades kubelet=1.32.2-1.1 kubeadm=1.32.2-1.1 kubectl=1.32.2-1.1
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

# crictl
# VERSION="v1.32.0"
# wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
# sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
# rm -f crictl-$VERSION-linux-amd64.tar.gz
# sudo chmod 777 /run/containerd/containerd.sock

# go (delete old and install)
cd
wget https://go.dev/dl/go1.24.4.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.24.4.linux-amd64.tar.gz

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

# doing this here as it opens new shell
sudo usermod -aG docker $USER
newgrp docker
