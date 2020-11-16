package main

import (
	"fmt"
	"net/http"
	"strings"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"
	"k8s.io/api/admission/v1beta1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/client-go/kubernetes"
)

var webhookCmd = &cobra.Command{
	Use:   "webhook",
	Short: "Starts pod validation webhook",
	Long:  "Starts pod validation webhook, which stops creation of the pod if runAsNonRoot is missing",
	Run:   startWebhook,
}

var webhookViper = viper.New()

var (
	podResource = metav1.GroupVersionResource{Version: "v1", Resource: "pods"}
)
var (
	universalDeserializer = serializer.NewCodecFactory(runtime.NewScheme()).UniversalDeserializer()
)

func init() {
	rootCmd.AddCommand(webhookCmd)

	webhookCmd.Flags().String("tls-cert-file", "",
		"Path to the certificate file. Required, unless --no-tls is set.")
	webhookCmd.Flags().Bool("no-tls", false,
		"Do not use TLS.")
	webhookCmd.Flags().String("tls-private-key-file", "",
		"Path to the certificate key file. Required, unless --no-tls is set.")
	webhookCmd.Flags().Int32("listen-port", 443,
		"Port to listen on.")

	if err := webhookViper.BindPFlags(webhookCmd.Flags()); err != nil {
		errorWithUsage(err)
	}

	webhookViper.AutomaticEnv()
	webhookViper.SetEnvKeyReplacer(strings.NewReplacer("-", "_"))
}

func startWebhook(cmd *cobra.Command, args []string) {
	config := &config{}
	if err := webhookViper.Unmarshal(config); err != nil {
		errorWithUsage(err)
	}

	if !config.NoTLS && (config.TLSPrivateKeyFile == "" || config.TLSCertFile == "") {
		errorWithUsage(errors.New("Both --tls-cert-file and --tls-private-key-file are required (unless TLS is disabled by setting --no-tls)"))
	}

	log.Debugf("Configuration is: %+v", config)

	//initialize kube client
	kubeClientSet, kubeClientSetErr := KubeClientSet(true)
	if kubeClientSetErr != nil {
		log.Fatal(kubeClientSetErr)
	}

	http.HandleFunc("/validate", admitFunc(validate).serve(config, kubeClientSet))

	addr := fmt.Sprintf(":%v", config.ListenPort)
	var httpErr error
	if config.NoTLS {
		log.Infof("Starting webserver at %v (no TLS)", addr)
		httpErr = http.ListenAndServe(addr, nil)
	} else {
		log.Infof("Starting webserver at %v (TLS)", addr)
		httpErr = http.ListenAndServeTLS(addr, config.TLSCertFile, config.TLSPrivateKeyFile, nil)
	}

	if httpErr != nil {
		log.Fatal(httpErr)
	} else {
		log.Info("Finished")
	}
}

func validate(ar v1beta1.AdmissionReview, config *config, clientSet *kubernetes.Clientset) *v1beta1.AdmissionResponse {
	reviewResponse := v1beta1.AdmissionResponse{}
	reviewResponse.Allowed = true

	raw := ar.Request.Object.Raw
	pod := corev1.Pod{}
	if _, _, err := universalDeserializer.Decode(raw, nil, &pod); err != nil {
		log.Error(err)
		return toAdmissionResponse(err)
	}
	// Retrieve the `runAsNonRoot` and `runAsUser` values.
	var runAsNonRoot *bool
	var runAsUser *int64
	if pod.Spec.SecurityContext != nil {
		runAsNonRoot = pod.Spec.SecurityContext.RunAsNonRoot
		runAsUser = pod.Spec.SecurityContext.RunAsUser
	}
	if runAsNonRoot == nil || *runAsNonRoot == false {
		reviewResponse.Allowed = false
		reviewResponse.Result = &metav1.Status{Code: 403, Message: "runAsNonRoot not specified right"}
		log.Infof("%q:%q:%q - %q", ar.Request.Kind.Kind, ar.Request.Namespace, ar.Request.Name, "runAsNonRoot not specified right")
		return &reviewResponse
	} else if *runAsNonRoot == true && (runAsUser != nil && *runAsUser == 0) {
		reviewResponse.Allowed = false
		reviewResponse.Result = &metav1.Status{Code: 403, Message: "runAsNonRoot specified, but runAsUser set to 0 (the root user)"}
		log.Infof("%q:%q:%q - %q", ar.Request.Kind.Kind, ar.Request.Namespace, ar.Request.Name, "runAsNonRoot specified, but runAsUser set to 0 (the root user)")
		return &reviewResponse
	}

	return &reviewResponse
}
