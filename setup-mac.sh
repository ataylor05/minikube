#!/bin/bash

# Check if OS is MacOS
if [ "$(uname)" = "Darwin" ]; then
    echo "OS is Darwin"
else
    echo "Wrong OS type, use the setup-linux.sh script."
    exit 1
fi

# Home Brew
if ! brew -v &> /dev/null; then
    echo "brew could not be found"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "brew found"
    brew update && brew upgrade
fi

# Check if docker is in path
if ! docker &> /dev/null; then
    echo "docker could not be found, installing"
    brew install --cask docker
else
    echo "docker found"
fi

# Check if docker is in path
if ! docker version &> /dev/null; then
    echo "docker not running, starting"
    launchctl start docker

else
    echo "docker running"
fi

# Check if minikube is in path
if ! minikube version &> /dev/null; then
    echo "kubectl could not be found, installing"
    brew install minikube
else
    echo "minikube found"
fi

# Check if kubectl is in path
if ! kubectl &> /dev/null; then
    echo "kubectl could not be found, installing"
    brew install kubectl
else
    echo "kubectl found"
fi

# Check if helm is in path
if ! helm version &> /dev/null; then
    echo "helm could not be found, installing"
    brew install helm
else
    echo "helm found"
fi

# Check if istioctl is in path
if ! istioctl version &> /dev/null; then
    echo "istioctl could not be found, installing"
    brew install istioctl
else
    echo "istioctl found"
fi

minikube start

# Install Metal LB
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
helm repo add metallb https://metallb.github.io/metallb
helm install --create-namespace --namespace metallb-system metallb metallb/metallb
while [[ -z $(kubectl get service -n metallb-system metallb-webhook-service -o jsonpath="{.status.loadBalancer}" 2>/dev/null) ]]; do
  echo "Waiting for metallb-webhook-service to get created"
  sleep 5
done
echo "svc/metallb-webhook-service exists"
kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250
EOF

# Install Istio Operator
istioctl operator init
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istiocontrolplane
spec:
  profile: default
EOF