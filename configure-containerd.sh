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
