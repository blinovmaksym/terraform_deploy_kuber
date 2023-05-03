#!/bin/bash

# Install Tekton CLI
curl -LO https://github.com/tektoncd/cli/releases/download/v0.30.1/tkn_0.30.1_Darwin_all.tar.gz
# Extract tkn to your PATH (e.g. /usr/local/bin)

echo "Extract"
sudo tar xvzf tkn_0.30.1_Darwin_all.tar.gz 
# --strip-components 1


echo "Install Tekton Pipelines"
# Install Tekton Pipelines
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton Triggers
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Install Tekton Operators
kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/latest/release.yaml


# Install Tekton Dashboard with LoadBalancer type service
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Update Tekton Dashboard service to use LoadBalancer
kubectl patch service tekton-dashboard -n tekton-pipelines --type='json' -p '[{"op":"replace","path":"/spec/type","value":"LoadBalancer"}]'





if ! curl -s -H "Authorization: token $TOKEN_TEKTON" https://api.github.com/user/keys | grep -q "Tekton SSH Key"; then
    ssh-keygen -t rsa -b 4096 -C "tekton@tekton.dev" -f tekton_key
    # save as tekton / tekton_key.pub
    # Get the public key contents
    public_key=$(cat tekton_key.pub)
    # Create a new SSH key on GitHub
    curl -X POST -H "Authorization: token $TOKEN_TEKTON" -d '{"title":"Tekton SSH Key","key":"'"${public_key}"'"}' https://api.github.com/user/keys


# create secret YAML from contents
cat tekton_key | base64 -w 0 > tekton_key_base64.txt
cat > tekton-git-ssh-secret.yaml << EOM
apiVersion: v1
kind: Secret
metadata:
    name: git-ssh-key
    annotations:
        tekton.dev/git-0: github.com
type: kubernetes.io/ssh-auth
data:
    ssh-privatekey: $(cat tekton_key_base64.txt)
---
EOM

kubectl apply -f tekton-git-ssh-secret.yaml
else    
    # Tekton SSH key exists on GitHub, skip generating and adding it
    echo "Tekton SSH key already exists on GitHub"

fi   
# create your Docker registry secret, for example:
cat > regsecret.yaml << EOM
kind: Secret
apiVersion: v1
metadata:
  name: regsecret
  annotations:
    tekton.dev/docker-0: https://index.docker.io/
type: kubernetes.io/basic-auth
stringData:
    username: $DOCKER_USERNAME
    password: $DOCKER_PASSWORD
EOM

kubectl apply -f regsecret.yaml
kubectl apply -f tekton/

echo "Test"
cd /usr/local/bin
ls
tkn version
#Install tasks  from Tekton Hub
tkn hub install task git-clone && tkn hub install task buildah