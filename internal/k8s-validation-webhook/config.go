package main

type config struct {
	NoTLS                            bool   `mapstructure:"no-tls"`
	TLSCertFile                      string `mapstructure:"tls-cert-file"`
	TLSPrivateKeyFile                string `mapstructure:"tls-private-key-file"`
	ListenPort                       int    `mapstructure:"listen-port"`
	Namespace                        string `mapstructure:"namespace"`
}
