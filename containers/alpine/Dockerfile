# syntax=docker/dockerfile:1.4

FROM alpine:3.16

ARG USER=devcontainer
ARG UID=54321

ENV HOME=/home/$USER

WORKDIR $HOME

RUN apk add --update \
        bash \
        ca-certificates \
        coreutils \
        curl \
        doas \
        doas-sudo-shim \
        git \
        gnupg \
        grep \
        htop \
        jq \
        krb5-libs \
        less \
        libgcc \
        libintl \
        libssl1.1 \
        libstdc++ \
        lsof \
        lttng-ust \
        man-pages \
        mandoc \
        nano \
        ncdu \
        ncurses \
        net-tools \
        openssh-client \
        procps \
        psmisc \
        rsync \
        sed \
        shadow \
        strace \
        tzdata \
        unzip \
        userspace-rcu \
        vim \
        wget \
        which \
        zip \
        zlib \
        zsh \
    && adduser -u $UID -s $(which zsh) -D $USER \
    && echo "permit nopass $USER as root" > /etc/doas.d/doas.conf \
    && chown -R $USER:$USER $HOME \
    && rm -rf /var/cache/apk/* /tmp/*

USER $USER

COPY --chown=$USER:$USER . .local/share/chezmoi

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID \
    GITHUB_ACCESS_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_API_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && doas rm -rf /var/cache/apk/* /tmp/*
CMD /bin/zsh
