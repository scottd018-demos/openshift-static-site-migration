operators:
	oc apply -f kubernetes/operators.yaml

cert-manager-route:
	oc apply -f https://github.com/cert-manager/openshift-routes/releases/latest/download/cert-manager-openshift-routes.yaml

DOMAIN ?= azure.dustinscott.io
APPS_DOMAIN ?= apps.$(DOMAIN)

#
# public certificates
#
AZURE_CERT_MANAGER_NEW_SP_NAME ?= apps-azure-dustinscott-io-dns-sp
AZURE_DNS_ZONE_RESOURCE_GROUP ?= dscott-permanent-rg
AZURE_SUBSCRIPTION_ID ?= $(shell az account show --output json | jq -r '.id')

azure-sp:
	az ad sp create-for-rbac --name $(AZURE_CERT_MANAGER_NEW_SP_NAME) --output json > azure-sp.json && \
	DNS_ID=$$(az network dns zone show --name $(DOMAIN) --resource-group $(AZURE_DNS_ZONE_RESOURCE_GROUP) --query "id" --output tsv) && \
	az role assignment create --assignee $$(cat azure-sp.json | jq -r '.appId') --role "DNS Zone Contributor" --scope $$DNS_ID

azure-secret:
	AZURE_CERT_MANAGER_SP_PASSWORD=$$(cat azure-sp.json | jq -r '.password') && \
	oc -n cert-manager create secret generic azure-dns --from-literal=client-secret="$${AZURE_CERT_MANAGER_SP_PASSWORD}" --dry-run=client -o yaml | oc apply -f -

public-issuer:
	AZURE_CERT_MANAGER_SP_APP_ID=$$(cat azure-sp.json | jq -r '.appId') && \
	AZURE_TENANT_ID=$$(cat azure-sp.json | jq -r '.tenant') && \
	cat kubernetes/public-issuer.yaml | \
	sed "s/AZURE_CERT_MANAGER_SP_APP_ID/$$AZURE_CERT_MANAGER_SP_APP_ID/g" | \
	sed "s/AZURE_SUBSCRIPTION_ID/$(AZURE_SUBSCRIPTION_ID)/g" | \
	sed "s/AZURE_TENANT_ID/$$AZURE_TENANT_ID/g" | \
	sed "s/AZURE_DNS_ZONE_RESOURCE_GROUP/$(AZURE_DNS_ZONE_RESOURCE_GROUP)/g" | \
	sed "s/AZURE_DNS_ZONE/$(DOMAIN)/g" | \
	oc apply -f -

#
# ingress controller
#
ingress-controller:
	oc apply -f kubernetes/ingress-controller.yaml

public-ip:
	@oc get svc -n openshift-ingress router-public -o json | jq -r '.status.loadBalancer.ingress[0].ip'

#
# pipelines
#
pipelines:
	oc apply -f kubernetes/pipelines.yaml
