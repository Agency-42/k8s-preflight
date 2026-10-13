# Minimal image for k8s-preflight: bash, kubectl, openssl, coreutils, grep, sed, awk.
FROM alpine:3.22

ARG KUBECTL_VERSION=v1.35.9
ARG TARGETARCH=amd64

LABEL org.opencontainers.image.title="k8s-preflight" \
      org.opencontainers.image.description="Read-only pre-flight checks before a Kubernetes minor upgrade" \
      org.opencontainers.image.source="https://github.com/Agency-42/k8s-preflight" \
      org.opencontainers.image.url="https://github.com/Agency-42/k8s-preflight" \
      org.opencontainers.image.documentation="https://agency42.se/en/articles/kubernetes-1-34-end-of-support-pre-flight-checklist" \
      org.opencontainers.image.vendor="Agency 42" \
      org.opencontainers.image.licenses="Apache-2.0"

RUN apk add --no-cache bash coreutils grep sed gawk openssl ca-certificates curl \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
 && curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" \
 && echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - \
 && chmod +x /usr/local/bin/kubectl \
 && rm /tmp/kubectl.sha256 \
 && apk del curl \
 && adduser -D -u 10001 preflight

COPY k8s-preflight /usr/local/bin/k8s-preflight
RUN chmod 0755 /usr/local/bin/k8s-preflight

USER 10001
ENTRYPOINT ["/usr/local/bin/k8s-preflight"]
CMD ["--help"]
