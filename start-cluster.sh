make start-lvmd-control-plane

# Check LVM resources
sudo pvs
sudo vgs
sudo lvs

make run

# Check status
kubectl get deployments -A
kubectl get pods -A --output=wide
kubectl get nodes
