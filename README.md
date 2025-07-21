# Multiple pods and pvcs with kubeadm init-made cluster. Two nodes: control-plane and worker on different vm:s.
# This directory should first be placed in the home directory of a machine with ssh connection to git and then run the installations.sh script.

Partially fixes the "sudo systemctl restart user@1000.service" error:
```console
sudo nano /etc/pam.d/common-session
session	optional	pam_systemd.so
-->
session	required	pam_systemd.so
logout & login
```

Give installations script rights and execute it. Do this on both the worker and control-plane.
```console
chmod +x ./installations.sh
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
kubectl get pods --all-namespaces
kubectl get nodes
kubectl get pods --all-namespaces --output=wide
kubectl get daemonsets --all-namespaces
kubectl get pvc --all-namespaces
kubectl get configmaps
sudo pvs
sudo vgs
sudo lvs
```

Scaling up:
```console
kubectl apply -f demo/statefulset.yaml
kubectl scale sts/web --replicas=3
```

## To clean up

---
Clean up STS:
```console
kubectl delete -f demo/statefulset.yaml
kubectl delete pvc -l app=nginx
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

---
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
