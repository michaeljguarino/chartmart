FROM bitwalker/alpine-elixir:1.13.4 AS builder

# The following are build arguments used to change variable parts of the image.
# The name of your application/release (required)
ARG APP_NAME
# The environment to build with
ARG MIX_ENV=prod

ENV APP_NAME=${APP_NAME} \
    MIX_ENV=${MIX_ENV}

# By convention, /opt is typically used for applications
WORKDIR /opt/app

# This step installs all the build tools we'll need
RUN apk update --allow-untrusted && \
  apk upgrade --no-cache && \
  apk add --no-cache \
    git \
    build-base && \
  mix local.rebar --force && \
  mix local.hex --force

# This copies our app source code into the build container
COPY . .

# needed so that we can get the app version from the git tag
RUN git config --global --add safe.directory '/opt/app'

RUN mix do deps.get, compile

RUN \
  mkdir -p /opt/built && \
  mix distillery.release --name ${APP_NAME} && \
  cp _build/${MIX_ENV}/rel/${APP_NAME}/releases/*/${APP_NAME}.tar.gz /opt/built && \
  cd /opt/built && \
  tar -xzf ${APP_NAME}.tar.gz && \
  rm ${APP_NAME}.tar.gz

FROM alpine:3.17.0 as tools

ARG TARGETARCH

# renovate: datasource=github-releases depName=helm/helm
ENV HELM_VERSION=v3.11.0

# renovate: datasource=github-releases depName=alco/goon
ENV GOON_VERSION=v1.1.1

# renovate: datasource=github-releases depName=pluralsh/plural-cli
ENV CLI_VERSION=v0.7.8

# renovate: datasource=github-releases depName=accurics/terrascan
ENV TERRASCAN_VERSION=v1.17.1

# renovate: datasource=github-releases depName=aquasecurity/trivy
ENV TRIVY_VERSION=v0.36.1

RUN apk add --update --no-cache curl ca-certificates unzip wget openssl && \
    # download helm
    curl -L https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz | tar xvz && \
    mv linux-${TARGETARCH}/helm /usr/local/bin/helm && \
    # download goon
    curl -L https://github.com/alco/goon/releases/download/${GOON_VERSION}/goon_linux_${TARGETARCH}.tar.gz | tar xvz && \
    mv goon /usr/local/bin/goon && \
    # download plural cli
    curl -L https://github.com/pluralsh/plural-cli/releases/download/${CLI_VERSION}/plural-cli_console_${CLI_VERSION/v/}_Linux_${TARGETARCH}.tar.gz | tar xvz plural && \
    mv plural /usr/local/bin/plural && \
    # download terrascan
    if [ "$TARGETARCH" = "amd64" ]; then \
      curl -L https://github.com/accurics/terrascan/releases/download/${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION/v/}_Linux_x86_64.tar.gz > terrascan.tar.gz; \
    else \
      curl -L https://github.com/accurics/terrascan/releases/download/${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION/v/}_Linux_${TARGETARCH}.tar.gz > terrascan.tar.gz; \
    fi && \
    tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz && \
    mv terrascan /usr/local/bin/terrascan && \
    # download trivy
    if [ "$TARGETARCH" = "amd64" ]; then \
      curl -L https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION/v/}_Linux-64bit.tar.gz > trivy.tar.gz; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      curl -L https://github.com/aquasecurity/trivy/releases/download/${TRIVY_VERSION}/trivy_${TRIVY_VERSION/v/}_Linux-ARM64.tar.gz > trivy.tar.gz; \
    fi && \
    tar -xf trivy.tar.gz trivy && rm trivy.tar.gz && \
    mv trivy /usr/local/bin/trivy && \
    # make tools executable
    chmod +x /usr/local/bin/helm && \
    chmod +x /usr/local/bin/goon && \
    chmod +x /usr/local/bin/plural && \
    chmod +x /usr/local/bin/terrascan && \
    chmod +x /usr/local/bin/trivy

FROM erlang:24.3.4.6-alpine

# The name of your application/release (required)
ARG APP_NAME
ARG GIT_COMMIT

RUN apk update && \
    apk add --no-cache \
      bash \
      curl \
      busybox \
      openssl-dev \
      ca-certificates \
      git

ENV REPLACE_OS_VARS=true \
    APP_NAME=${APP_NAME} \
    GIT_COMMIT=${GIT_COMMIT}

WORKDIR /opt/app

# Create plural user and home directory, set owner to plural
RUN addgroup -g 10001 plural && \
    adduser -s /bin/sh -u 10001 -G plural -h "/opt/app" -S -D plural && \
    chown -R 10001:10001 "/opt/app"

COPY --from=tools /usr/local/bin/plural /usr/local/bin/plural
COPY --from=tools /usr/local/bin/helm /usr/local/bin/helm
COPY --from=tools /usr/local/bin/goon /usr/local/bin/goon
COPY --from=tools /usr/local/bin/terrascan /usr/local/bin/terrascan
COPY --from=tools /usr/local/bin/trivy /usr/local/bin/trivy
COPY --from=builder --chown=10001:10001 /opt/built .

USER plural

CMD trap 'exit' INT; /opt/app/bin/${APP_NAME} foreground
