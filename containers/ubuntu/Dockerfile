# syntax=docker/dockerfile:1.29@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM buildpack-deps:noble-curl@sha256:a115b80bacdfad86050664accdf7e2d7be45edb87d98a3ba78b78f0f9a089c1a AS base
ARG USER
ARG UID

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

# hadolint ignore=DL3008
RUN --mount=type=secret,id=CUSTOM_CA,dst=/run/secrets/custom_ca.pem,required=false \
    --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    set -eux \
    && if [ -s /run/secrets/custom_ca.pem ]; then cp /run/secrets/custom_ca.pem /usr/local/share/ca-certificates/custom-ca.pem && update-ca-certificates; fi \
    && groupadd --gid "$UID" "$USER" \
    && useradd -s /bin/bash --uid "$UID" --gid "$USER" -m "$USER" \
    && mkdir -p /etc/sudoers.d \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER" \
    && chmod 0440 "/etc/sudoers.d/$USER" \
    && chown -R "$USER:$USER" "/home/$USER" \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        libatomic1 \
        locales \
        lsb-release \
        sudo \
        unzip \
        zip \
        zsh \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && chsh -s "/usr/bin/zsh" "$USER"

FROM base AS setup
ARG USER
ARG UID

ENV HOME=/home/$USER
WORKDIR $HOME
COPY --chown=$USER:$USER . .local/share/chezmoi
USER $USER
CMD ["/usr/bin/zsh"]

FROM setup AS test
ARG CACHE_BUST
ARG USER
ARG UID
ARG WITHOUT_TOOLCHAINS=true

RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=mise,target="${HOME}/.local/share/mise",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=rustup,target="${HOME}/.local/share/rustup",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=cargo,target="${HOME}/.local/share/cargo",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=helm,target="${HOME}/.local/share/helm",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN="$( [ -f /run/secrets/github_token ] && cat /run/secrets/github_token || true )" \
    && CI=true \
    && MISE_ALWAYS_KEEP_DOWNLOAD=true \
    && export CI GITHUB_TOKEN MISE_ALWAYS_KEEP_DOWNLOAD \
    && WITHOUT_TOOLCHAINS="$WITHOUT_TOOLCHAINS" .local/share/chezmoi/install.sh --data=false \
    && zsh -lic 'mise trust ~/.local/share/chezmoi && mise -C ~/.local/share/chezmoi run test' \
    && echo "Cache bust: $CACHE_BUST"

FROM setup
ARG CACHE_BUST
ARG USER
ARG UID

RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$([ -f /run/secrets/github_token ] && cat /run/secrets/github_token || true) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && echo "Cache bust: $CACHE_BUST"
