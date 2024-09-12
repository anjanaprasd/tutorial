#!/bin/bash

set -e

#variables
CONTAINERD_VERSION=1.7.14
CNI_VERSION=1.5.0
CRI_VERSION="v1.28.0"
RUNC_VERISON=1.1.12
K8_VERSION=1.30
OS=$1

trap 'echo "Script exited with code $?"; exit $?' EXIT

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi


echo "os is $OS"
if [ -z "$OS" ]; then
  echo "Error: 'os' variable is not set."
  echo "Usage: ./k8-setup.sh <os>"
  echo "Valid inputs for <os> are: ubuntu, alma, rhel, centos"
  exit 2
fi



echo -e "033[1;32mDisabling SE-Linux\033[0m"
setenforce 0 &&  sed -i 's/enforcing/disabled/g' /etc/selinux/config
#after se-linux change we need to do a server reboot will do it last stage.
sleep 2 

echo "Disable Swap memory"
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo -e " " 

if ! grep -q "SwapTotal: 0 kB" /proc/meminfo; then
    echo "Swap is disabled."
else
    echo "Failed to disable swap."
    exit 3
fi


sleep 2

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF


modprobe overlay
modprobe br_netfilter

echo -e " " 

sleep 2

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sleep 2

sysctl --system &> /dev/null

echo -e " " 

echo "Verify that the br_netfilter, overlay modules are loaded"

echo -e " " 

lsmod | grep -e br_netfilter -e overlay && echo -e "\n\nKernel modules are loaded successfully" || { echo "Kernel modules are not loaded successfully"; exit 4; }

echo -e " " 

echo "Verifying sysctl configurations.."

echo -e " " 

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward


echo -e "\n\n\033[1;32mSystem configurations are successfully completed.\033[0m"

sleep 5

echo -e " " 

echo -e "\033[34mStarting Containerd Installation and Service Configuration....\033[0m"



curl -s -LO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

ctr --version &> /dev/null || { echo "Containerd is not installed"; exit 5; }
mkdir -p /usr/local/lib/systemd/system/ && sudo mkdir -p /etc/containerd
wget -P /usr/local/lib/systemd/system/ https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
cgvalue=$(grep SystemdCgroup /etc/containerd/config.toml | awk -F '=' '{print $2}' | tr -d ' ')

sleep 2

echo -e " " 


if [ "$cgvalue" = true ]; then
  echo -e "\nSystemdCgroup value is true"
else
  echo -e "\nSystemdCgroup value is false"
  echo "Please check the last change..."
  exit 6
fi

systemctl daemon-reload
systemctl enable --now containerd

systemctl status containerd &> /dev/null  || { echo "containerd is not installed"; exit 7; }


echo -e "\033[32mInstalling RUNC Package...\033[0m"
curl -s -LO https://github.com/opencontainers/runc/releases/download/v${RUNC_VERISON}/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc


sleep 2


curl -s -LO https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v${CNI_VERSION}.tgz > /dev/null 2>&1 

echo -e " "

echo -e "\033[34mInstalling CRTL pacakge on node....\033[0m"


curl -s -LO https://github.com/kubernetes-sigs/cri-tools/releases/download/$CRI_VERSION/crictl-$CRI_VERSION-linux-amd64.tar.gz
tar -C /usr/local/bin -xzvf crictl-$CRI_VERSION-linux-amd64.tar.gz > /dev/null 2>&1 

tee /etc/crictl.yaml <<EOF    
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

crictl --version &> /dev/null || { echo "crictl is not installed"; exit 8; }

crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock

echo -e " " 

echo -e "\033[32mContainer Runtime configuration is completed...\033[0m"


rhel_k8 () {

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${K8_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${K8_VERSION}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

yum repolist | grep kubernetes || echo "Repo Adding is not successfull"

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl enable --now kubelet


}


ubuntu_k8 () {
    
[ -d "/etc/apt/keyrings" ] || mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet

}


if [ "$OS" == "ubuntu" ] ; then
  echo "Starting package installtion on ubuntu system"
  ubuntu_k8 || exit 9
else
  echo "Starting package installtion on RHEL system"
  rhel_k8 || exit 10
fi



echo -e "\033[32mPrinting versions of installed Packages......\033[0m"

echo ""

echo "Kubelet version:"
kubelet --version

echo -e " " 

echo "Kubeadm version:"
kubeadm version

echo -e " "

echo "Kubectl version:"
kubectl version --client

echo -e " "

echo "Containerd version:"
containerd --version

echo -e " "

echo -e "\033[32mKubeadm installtion is completed on the server and starting server reboot....\033[0m"

sleep 2

init 6


