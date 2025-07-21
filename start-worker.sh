make start-lvmd-worker

# Check LVM resources
sudo pvs
sudo vgs
sudo lvs

make create-worker IP=$1 TOKEN=$2 HASH=$3
