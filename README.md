# Kubernetes Admission Controller Webhook Demo

This repository contains a small HTTP server that can be used as a Kubernetes
[ValidatingAdmissionWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook).

The logic of this demo webhook is fairly simple: it enforces more secure defaults for running
containers as non-root user. If `runAsNonRoot` is set to `false` or no correct value is set for `runAsNonRoot`, it will faile the request and return error.

## Reference solution
* The [maniSbindra/k8s-delete-validation-webhook](https://github.com/maniSbindra/k8s-delete-validation-webhook) is been referenced for initialization / configuration of this application.
* The [stackrox/admission-controller-webhook-demo](https://github.com/stackrox/admission-controller-webhook-demo) is been referenced for create and update resource validations.

## Installation
* **Building and Pushing the container image** :The **Make target docker-build or docker-build-local** can be used to create the container image. The **make docker-push**  makefile target can be used to push the container image to the container registry. With the **make docker-build-local** makefile target you need dependencies like glide on your machine, the **make docker-build** makefile target uses a multi stage build for building the go binary. Make sure you change the values of **CONTAINER_NAME**, **CONTAINER_VERSION** in the Make file.
* The [ **deployments/webhook-k8s-resources.template.yaml**](https://github.com/cici37/k8s-validation-webhook/blob/master/deployments/webhook-k8s-resources.template.yaml#L7) is the kubernetes manifest template for this solution. The main kubernetes resources to be created are ValidatingWebhookConfiguration, a deployment and a service. The template has place holders for the [TLS Certificate], the [TLS Key], the [CA Bundle] and the container image.
* The [Steps](https://github.com/avast/k8s-admission-webhook#example-configuration) mentioned of the avast repository explain how to replace values in the yaml template file. Instead of manually doing it you can using the **make gen-k8s-manifests** Makefile target from this solution. This is described in more detail as follows
* The makefile target **make gen-k8s-manifests** in this solution has all steps to replace values in the template, and as an output it generates the deployments/webhook-k8s-resources.yaml which has certificate, key and the ca bundle in the yaml. To execute this make target **you need to have access to the target kubernets** cluster (KUBECONFIG or ./kube/config). Before running the make target, verify that the values of the **CONTAINER_NAME, CONTAINER_VERSION, WEBHOOK_NAMESPACE and WEBHOOK_SERVICE_NAME** in the Makefile are correct.  
* After this applying the generated **deployments/webhook-k8s-resources.yaml** file creates all required kubernetes resources. By default entry for this generated file is in the .gitignore file.

### Commands
* Clone the repo
  ```sh
  git clone https://github.com/cici37/k8s-validation-webhook.git
  ```
* Modify Makefile values for **CONTAINER_NAME, CONTAINER_VERSION, WEBHOOK_NAMESPACE and WEBHOOK_SERVICE_NAME**
* Make sure you are logged in to the container registry and have access to the kubernetes cluster
* Build and Push container image
  ```sh
  make docker-build
  make docker-push
  ```
* Generate certs, keys and generate actual yaml from yaml template.
  ```sh
  make gen-k8s-manifests
  ```
* Apply the yaml
  ```sh
  kubectl apply -f deployments/webhook-k8s-resources.yaml
  ```

## Verify installation
* Check the deployment k8s-delete-validation-webhook, for which a pod should be running
  ```sh
  kubectl get deploy k8s-validation-webhook
  ```
* add the label webhook=enabled to the default namespace. Note this is the default value and can be changed in [**the namespace selector**](https://github.com/maniSbindra/k8s-delete-validation-webhook/blob/9f86e415d4365c66f484e5a543935e950f3026a1/deployments/webhook-k8s-resources.template.yaml#L107)
  ```sh
  kubectl label namespace default webhook=enabled
  ```
* Create pods with examples
  ```sh
  $ kubectl create -f examples/pod-with-defaults.yaml
  $ kubectl create -f examples/pod-with-override.yaml
  $ kubectl create -f examples/pod-with-conflict.yaml 
  $ kubectl create -f examples/pod-with-userset.yaml 
  ```
* First three creation should fail by webhook
