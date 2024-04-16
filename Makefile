operators:
	oc apply -f kubernetes/operators.yaml

DOMAIN ?= apps.dustinscott.io

#
# public certificates
#
register-domain:
	curl -s -X POST https://auth.acme-dns.io/register | jq -r '{"$(DOMAIN)": .}' > register.json

register-cname:
	@cat register.json | jq -r '."$(DOMAIN)".fulldomain'

register-secret:
	@oc -n cert-manager create secret generic acme-dns --from-file=register.json

public-issuer:
	oc apply -f kubernetes/public-issuer.yaml

#
# ingress controller
#
ingress-controller:
	cat kubernetes/ingress-controller.yaml | sed "s/apps.dustinscott.io/$(DOMAIN)/g" | oc apply -f -

public-ip:
	@oc get svc -n openshift-ingress router-public -o json | jq -r '.status.loadBalancer.ingress[0].ip'
