**Using the development environment from the repository:**
- 1. Have the ssh rights on machine
- 2. Open README.md 
- (2.5. make edits to scripts' make commands based on if you use Tilt for development or not)
- 3. Follow instructions

NOTE! The tilt setup is not working completely for development. Building the local edits onto an image can be done using the TopoLVM official "example" kind cluster and changing the Makefile BUILD_IMAGE flag to true.

**Generally, main points of using TopoLVM within the cluster's logical volume management:**
- With Helm, remember to...
	- Allocate file with necessary space and set up a volume group to it
	- Build lvmd binary & start lvmd service
	- Create namespace topolvm-system
	- Apply cert-manager (installation possible via topolvm helm chart) or use your own TLS certificates (helm needs cert-manager)
	- Add & update helm repository
		- topolvm https://topolvm.github.io/topolvm (not necessary with local charts)
		- jetstack https://charts.jetstack.io
	- Ignore topolvm.io related webhooks
	-  Build dependency & install topolvm via Helm!
		- have either values.yaml with "cert-manager. enabled: true" or set it via "--set cert-manager.enabled=true"
	- Apply PVC:s related to Pods, have storageClassName be "topolvm-provisioner" or "topolvm-provisioner-thin"


```console
./start-cluster.sh

./start-worker.sh x y z
echo 'maxPods: 1300' | sudo tee -a /var/lib/kubelet/config.yaml
sudo systemctl restart kubelet

sudo -E tilt up

ssh -L 10350:localhost:10350 testvm-1

make complete-worker WORKERNAME=<node-name>
kubectl scale sts/web --replicas=100

sudo lvscan
sudo pvs
sudo vgs
sudo lvs
kubectl get daemonsets -A
kubectl get pvc --output=wide
kubectl get nodes -o yaml

crictl pods

kubectl logs -n topolvm-system topolvm-node-<rand-string> --timestamps | grep -i "NodePublishVolume" >> logs.txt
```
