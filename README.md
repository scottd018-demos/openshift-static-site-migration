# Summary

This repo shows a simple modern workflow for a traditional HTML website serving static content.  It includes 
the following:

1. A pipeline to deploy the latest content (using [OpenShift Pipelines](https://docs.openshift.com/pipelines/1.14/about/understanding-openshift-pipelines.html))
2. A [source-to-image](https://docs.openshift.com/container-platform/4.14/openshift_images/using_images/using-s21-images.html) process to deliver the content as a container
3. An automated certificate rotation using [public certificates with cert-manager](https://docs.openshift.com/container-platform/4.14/security/cert_manager_operator/cert-manager-operator-issuer-acme.html)


## Personas

This walkthrough makes use of 2 personas:

1. Cluster Admin - responsible for platform setup and configuration as well as external configuration such as DNS.  
In this walkthrough, the relevant examples are:

* Operators such as cert-manager
* Ingress for the public domain
* Certificate Issuer configuration for requesting public certificates
* Re-usable pipeline resources

1. Developer - responsible for submitting website code into a git repo and monitoring pipelines upon updates


## Walkthrough

This walkthrough assumes that the cluster admin has access to the following:

* A public DNS domain - this is a domain that is available on the public internet and is able to have DNS records 
inserted by the cluster admin.  The DNS records are both to allow ingress into the cluster, and to request public
certificates to front the website


### Cluster Admins

1. First, we must ensure that we have all of the appropriate operators installed:

```bash
make operators
```

1. Next, if one does not already exist, we must create an ingress controller that is tied to our public domain:

```bash
DOMAIN=example.com make ingress-controller
```

1. Next, if one does not already exist, we must create a DNS record for the public domain that is tied back 
to the ingress controller that we just created:

```bash
make public-ip

# output sample:
# 40.10.10.10
```

Using the above example, I would want to create a DNS record for `*.example.com` that points to `40.10.10.10`.  This 
means that all DNS records under `example.com` (e.g. `mysite.example.com`) will be routed to `40.10.10.10` which is 
the public IP for the ingress load balancer.  The internal ingress controller handles routing of traffic to the 
appropriate services in the cluster based on the `Route` configuration.

To ensure that this record works appropriately, you can do the following (using a fake record and your domain as a substitute) 
which should tie back to the ingress controller IP above:

```bash
nslookup fake.example.com

# output sample:
# Server:         172.100.0.1
# Address:        172.100.0.1#53

# Non-authoritative answer:
# Name:   test.example.com
# Address: 40.10.10.10
```

> **NOTE:** the below is for ease of walkthrough.  Be sure to use with caution if using for anything but a walkthrough.

1. Next, we need to register a domain so that we have the ability to request public certificates from an ACME server.  
This can be done one of MANY ways.  We are going to assume no API is used, so we will manually register a domain with 
ACME DNS.  If you have a domain such as Route53/AzureDNS, feel free to skip this step, but understand you will need to 
configure your issuer appropriately (see `kubernetes/public-issuer.yaml`).

```bash
make register-domain
```

The DNS record from the above command needs to be registered as a CNAME in your DNS server to point from 
`_acme-challenge.example.com` back to the output of `fulldomain`, assuming `example.com` is your domain.  You can get 
this record that you must insert by:

```bash
make register-cname

# output sample:
# <GUID>.auth.acme-dns.io
```

Once you have created the above record as a CNAME for `_acme-challenge.example.com`, we need to create the registration 
JSON as a secret in your cluster.

```bash
make register-secret
```

Finally, you can register the domain by creating the ClusterIssuer for your public domain and a wildcard certificate.

```bash
make public-issuer
```
