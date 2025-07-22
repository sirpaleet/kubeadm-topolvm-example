# Multiple pods and pvcs with kubeadm init-made cluster. Two nodes: control-plane and worker on different vm:s.
## This directory should first be placed in the home directory of a machine with ssh connection to git and then run the installations.sh script.

Add environment variables:
```console
echo 'export PATH=/home/ubuntu/.krew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/usr/local/go/bin' >> ~/.bashrc
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
echo 'LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' >> ~/.bashrc
echo 'LD_RUN_PATH=$LD_RUN_PATH:/usr/local/lib' >> ~/.bashrc
echo 'CONTAINER_RUNTIME_ENDPOINT=unix:///run/containerd/containerd.sock' >> ~/.bashrc
echo 'export SKIP_TESTS_USING_ROOT=1' >> ~/.bashrc
source ~/.bashrc
```

Partially fixes the "sudo systemctl restart user@1000.service" error:
1. Open file:
```console
sudo nano /etc/pam.d/common-session
```
2. Change line:
session	optional	pam_systemd.so
-->
session	required	pam_systemd.so
3. Lastly:
logout & login

Install required packages and configure. Do this on both the worker and control-plane.
```console
./installations.sh
```

Run on the control-plane intended vm:
```console
./start-cluster.sh
```

Run on worker vm:
```console
./start-worker.sh <ip-address> <token> <ca-cert-hash>
```

On the control-plane intended vm:
```console
make finish-run
make complete-worker WORKERNAME=<worker-name>
```

## To re-setup only worker node (after delete)

Run on worker vm:
```console
./start-worker.sh <ip-address> <token> <ca-cert-hash>
```
On the control-plane intended vm:
```console
make complete-worker WORKERNAME=<worker-name>
```

## To see nodes' info

On control-plane vm:
```console
kubectl get deployments -A
kubectl get pods -A
kubectl get nodes
kubectl get pods -A --output=wide
kubectl get daemonsets -A
kubectl get pvc -A
kubectl get configmaps
sudo pvs
sudo vgs
sudo lvs
```

IMPORTANT!!! -- Edit pod limits:
```console
sudo nano /var/lib/kubelet/config.yaml 
"
kind: KubeletConfiguration
maxPods: 1300
"
sudo systemctl restart kubelet
```

Scaling up:
```console
kubectl scale sts/web --replicas=<wanted-amount>
```

## To clean up

---
Clean up STS (also part of remove-worker):
```console
make remove-pods
```

Scaling down:
```console
kubectl scale sts/web --replicas=1
kubectl get pods
kubectl get pvc
kubectl delete pvc <name>
```

---
If you do not intend to reuse node:
On control-plane vm:
```console
make remove-worker WORKERNAME=<worker-name>
```
On worker vm:
```console
./kill-worker.sh
```
OR

If you intend to reuse node:

On control-plane vm:
```console
make drain-worker WORKERNAME=<worker-name>
```

---
And to finally kill the cluster:

On control-plane vm:
```console
./kill-cluster.sh <worker-name>
```
