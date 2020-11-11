CONTAINER_NAME=gcr.io/cicih-gke-dev/validate-webhook-demo
CONTAINER_VERSION=demo
WEBHOOK_NAMESPACE=default
WEBHOOK_SERVICE_NAME=k8s-validation-webhook
WEBHOOK_IMAGE=$(CONTAINER_NAME):$(CONTAINER_VERSION)



fmt:
	go fmt ./internal/k8s-validation--webhook/

vet:
	go vet ./internal/k8s-validation-webhook/

test:
	go test ./internal/k8s-validation-webhook/ -v

build: 
	cd internal/k8s-validation-webhook/ && glide install -v &&  CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo

# go build done using multistage container build
docker-build:
	docker build -t $(CONTAINER_NAME):$(CONTAINER_VERSION) -f build/Dockerfile .

# go build done locally and copied into container image
# debugging with vscode squash extension or squashctl only seems to work with the local build
docker-build-local:
	cd internal/k8s-validation-webhook/ && glide install -v &&  CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o k8s-validation-webhook
	docker build -t $(CONTAINER_NAME):$(CONTAINER_VERSION) -f build/Dockerfile-local-go-build .

docker-push:
	docker push $(CONTAINER_NAME):$(CONTAINER_VERSION)

# This generates the actual kubernetes manifests using the manifest template. First using the conntection to the kubernetes cluster certificate and key are generated for the the webook. Then the certificate, key and manifest values are injected into the kubernetes manifest template (deployments/webhook-k8s-resources.template.yaml) to get the actual kubernetes manifest (deployments/webhook-k8s-resources.yaml). Once this kubernetes manifest is applied, the solution is deployed to the cluster ( Assuming that the container image is already present in the container registry mentioned in this Makefile's variable configuration)
gen-k8s-manifests:
	if [ -f create-signed-cert.sh ]; then rm create-signed-cert.sh ; fi
	if [ -f csr.conf ]; then rm csr.conf ; fi
	if [ -f server-cert.pem ]; then rm server-cert.pem ; fi
	if [ -f server-key.pem ]; then rm server-key.pem ; fi
	if [ -f server.csr ]; then rm server.csr ; fi
	curl -sL https://raw.githubusercontent.com/avast/k8s-admission-webhook/master/test/create-signed-cert.sh -o ./create-signed-cert.sh
	chmod +x ./create-signed-cert.sh
	./create-signed-cert.sh --namespace $(WEBHOOK_NAMESPACE) --service $(WEBHOOK_SERVICE_NAME) && sleep 2
	# WEBHOOK_TLS_CERT=$$(tr '\n' '~' <  server-cert.pem | sed 's/~//g')
	# WEBHOOK_TLS_CERT=$$(tr '\n' '?' <  server-cert.pem | sed 's/?/?     /g') && cat deployments/webhook-k8s-resources.template.yaml | sed 's~\$${WEBHOOK_TLS_CERT}~'"$$WEBHOOK_TLS_CERT"'~g' | tr '?' '\n' | sed '/^ *$$/d' > yaml-with-tls-cert.yaml
	# WEBHOOK_TLS_PRIVATE_KEY_B64=$$(cat server-key.pem | base64 | tr -d '\n') && cat yaml-with-tls-cert.yaml | sed 's~\$${WEBHOOK_TLS_PRIVATE_KEY_B64\}~'"$$WEBHOOK_TLS_PRIVATE_KEY_B64"'~g' > yaml-with-cert-and-key.yaml
	# WEBHOOK_CA_BUNDLE=$$(kubectl get configmap -n kube-system extension-apiserver-authentication -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n') && cat yaml-with-cert-and-key.yaml | sed 's~\$${WEBHOOK_CA_BUNDLE\}~'"$$WEBHOOK_CA_BUNDLE"'~g' > yaml-with-cert-and-key-and-cabundle.yaml && sed 's~\$${WEBHOOK_IMAGE\}~'"$(WEBHOOK_IMAGE)"'~g' yaml-with-cert-and-key-and-cabundle.yaml > final.yaml
	WEBHOOK_TLS_CERT=$$(tr '\n' '?' <  server-cert.pem | sed 's/?/?    /g') && WEBHOOK_TLS_PRIVATE_KEY_B64=$$(cat server-key.pem | base64 | tr -d '\n') && WEBHOOK_CA_BUNDLE=$$(kubectl get configmap -n kube-system extension-apiserver-authentication -o=jsonpath='{.data.client-ca-file}' | base64 | tr -d '\n') && cat deployments/webhook-k8s-resources.template.yaml | sed 's~\$${WEBHOOK_TLS_CERT}~'"$$WEBHOOK_TLS_CERT"'~g' | tr '?' '\n' | sed '/^ *$$/d' | sed 's~\$${WEBHOOK_TLS_PRIVATE_KEY_B64\}~'"$$WEBHOOK_TLS_PRIVATE_KEY_B64"'~g' | sed 's~\$${WEBHOOK_CA_BUNDLE\}~'"$$WEBHOOK_CA_BUNDLE"'~g' | sed 's~\$${WEBHOOK_IMAGE\}~'"$(WEBHOOK_IMAGE)"'~g' > deployments/webhook-k8s-resources.yaml
	rm create-signed-cert.sh csr.conf server-cert.pem server-key.pem server.csr

