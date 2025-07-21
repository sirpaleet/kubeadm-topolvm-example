make start-lvmd-control-plane

# Check LVM resources
sudo pvs
sudo vgs
sudo lvs

make run

# Check status
kubectl get deployments -A
kubectl get pods --all-namespaces
kubectl get nodes
