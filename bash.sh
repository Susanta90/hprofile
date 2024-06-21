#!/bin/bash

sudo eksctl create iamserviceaccount \
  --cluster=demo-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --region=us-east-1 \
  --attach-role-arn arn:aws:iam::637423293208:role/aws-service-controller-eks-role \
  --approve

# eksctl get iamserviceaccount --cluster demo-cluster

helm repo add eks https://aws.github.io/eks-charts

helm repo update eks

#helm repo remove eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set  image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller \
  --set image.tag=v2.7.1 \
  --set region=us-east-1 \
  --set vpcId=vpc-07d3c084b26a40ddd

#helm unstall aws-load-balancer-controller 

# Deploy EBS CSI Driver
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

#kubectl delete -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"

# Verify ebs-csi pods running
kubectl get pods -n kube-system