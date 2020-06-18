# Azure AKS Infrastructure Repo

## Summary 
This repository will help you quickly get up and running with AKS, 
be it via Azure Resource Manager (ARM), or with Terraform.

## Overview
Pictured is the infrastructure deployed via Terraform:

* VNet
* Two Subnets
  * Windows Node Subnet
  * Linux Node Subnet
* Windows AKS Nodepool (set to 1 node)
* Linux AKS Nodepool (set to 1 node)
* Load Balancer

The ARM wizard is much more simple, and is a good start if you've yet to work with AKS, 
and/or don't require a Windows nodepool:

* Linux AKS Nodepool (default 1 node) 
* Load Balancer

### ARM Deployment
This repo supports the "Deply to Azure" button, hence the JSON files in the root. 

To do so, simply click on the following button:
[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

## Details
The cluster itself, as well as this repo, were made to support deployments via Azure Devops, 
as well as to demonstrate Datadog monitoring. That being said, feel free to fork and play
with the manifests in the `k8s` folder!

