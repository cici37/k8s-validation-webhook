FROM golang:1.10-stretch AS builder

RUN curl https://glide.sh/get | sh

WORKDIR /go/src/github.com/cici37/k8s-validation-webhook

COPY internal/k8s-validation-webhook/glide.* /go/src/github.com/cici37/k8s-validation-webhook/
RUN glide install -v

COPY internal/k8s-validation-webhook/*.* ./

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo

FROM alpine:latest

COPY --from=builder /go/src/github.com/cici37/k8s-validation-webhook/k8s-validation-webhook /k8s-validation-webhook/internal/k8s-validation-webhook

ENTRYPOINT ["/k8s-validation-webhook/internal/k8s-validation-webhook", "webhook"]
