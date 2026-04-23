# Bootstrap Flow

1. Create the Lima VMs  
   `./scripts/create.sh`

2. Configure `/etc/hosts` on all nodes  
   `./scripts/hosts.sh`

3. Install containerd and Kubernetes packages  
   `./scripts/bootstrap.sh`

4. Apply kernel and kubelet prerequisites  
   `./scripts/prep.sh`

5. Initialize the first control plane  
   `./scripts/init-cp1.sh`

6. Configure `kubectl` on `cp1`  
   `./scripts/configure-kubectl.sh`

7. Install Flannel  
   `./scripts/install-flannel.sh`

8. Join the remaining control planes and workers  
   `./scripts/join-all.sh`

9. Export kubeconfig to the Mac host  
   `./scripts/export-kubeconfig.sh`

10. Use the cluster from the host  
    `export KUBECONFIG=$PWD/kubeconfig`

11. Verify the cluster  
    `kubectl get nodes -o wide`
