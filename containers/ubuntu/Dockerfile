# syntax=docker/dockerfile:1.14

FROM buildpack-deps:noble-curl

ARG USER=devcontainer
ARG UID=54321

ENV HOME=/home/$USER

WORKDIR $HOME
# https://github.com/microsoft/vscode-dev-containers/blob/main/containers/ubuntu/.devcontainer/library-scripts/common-debian.sh#L77
RUN set -eux \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
              apt-transport-https \
              bash \
              ca-certificates \
              curl \
              dialog \
              dirmngr \
              gnupg2 \
              init-system-helpers \
              iproute2 \
              jq \
              less \
              libc6 \
              libgcc1 \
              libgssapi-krb5-2 \
              libicu[0-9][0-9] \
              libkrb5-3 \
              liblttng-ust[0-9] \
              libstdc++6 \
              locales \
              lsb-release \
              lsof \
              man-db \
              manpages \
              manpages-dev \
              nano \
              ncdu \
              net-tools \
              openssh-client \
              procps \
              psmisc \
              rsync \
              strace \
              sudo \
              unzip \
              vim-tiny \
              wget \
              zip \
              zlib1g \
              zsh \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && groupadd --gid $UID $USER \
    && useradd -s $(command -v zsh) --uid $UID --gid $USER -m $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER \
    && chown -R $USER:$USER $HOME \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/log/* /tmp/*

USER $USER

COPY --chown=$USER:$USER . .local/share/chezmoi

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID \
    GITHUB_ACCESS_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_API_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && sudo rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/log/* /tmp/*

CMD /bin/zsh
