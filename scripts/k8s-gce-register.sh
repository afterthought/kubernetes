#!/bin/bash

# Adds couchbase to an existing cluster on GCE
#
# Assumes you have a running kubernetes cluster
# created with `echo curl -sS https://get.k8s.io | bash`
# or a local Kubernetes source folder where
# kubernetes/cluster/kube-up.sh was run

CBUSER=user
CBPASSWORD=user

SKYDNS_DOMAIN=default.svc.cluster.local


# pods
printf "\nCreating pods ...\n"
kubernetes/cluster/kubectl.sh create -f pods/app-etcd.yaml

printf "\nWaiting for cluster to initialise ...\n"
sleep 20
kubernetes/cluster/kubectl.sh create -f services/app-etcd.yaml

# config file adjustments
printf "\nAdjusting config files ..."
PODIP="app-etcd-service.$SKYDNS_DOMAIN"
sleep 5

gcloud --quiet compute ssh kubernetes-master --command "curl --silent -L http://localhost:8080/api/v1beta3/proxy/namespaces/default/pods/app-etcd:2379/v2/keys/couchbase.com/userpass -X PUT -d value='$CBUSER:$CBPASSWORD'"

NODE1=$(gcloud compute instances list --format json | ./nodes.js | awk 'NR==1{print $1}')
NODE2=$(gcloud compute instances list --format json | ./nodes.js | awk 'NR==2{print $1}')

# Best practice to create pods/RC's before services
# replication-controllers
printf "\nCreating replication-controllers ...\n"
kubernetes/cluster/kubectl.sh create -f replication-controllers/couchbase-server.yaml

# services
printf "\nCreating services ...\n"
kubernetes/cluster/kubectl.sh create -f services/couchbase-service.yaml

# firewall and forwarding-rules
printf "\nCreating firewall and forwarding-rules ...\n"
gcloud compute firewall-rules create cbs-8091 --allow tcp:30891 --target-tags kubernetes-minion

# Done.
CBNODEIP=$(gcloud compute instances describe $NODE1 --format json | jsawk 'return this.networkInterfaces[0].accessConfigs[0].natIP')

# Can goto any k8s minion and get there, or go through the master
printf "\nDone\n\n. Go to http://$CBNODEIP:30891\n\n or \n http://<k8smaster>:8080/api/v1beta3/proxy/namespaces/default/services/couchbase-service:8091/".
