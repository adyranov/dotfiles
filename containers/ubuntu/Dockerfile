# syntax=docker/dockerfile:1.20@sha256:26147acbda4f14c5add9946e2fd2ed543fc402884fd75146bd342a7f6271dc1d

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM buildpack-deps:noble-curl@sha256:12bbe6a019ebb73425417dd8a1c7376d9c23d5bbd151e69db126a9192eb408df AS base
ARG USER
ARG UID

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

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
    && chown -R "$USER:$USER" "$HOME" \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        locales \
        lsb-release \
        sudo \
        unzip \
        wget \
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

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,id=mise,target="${HOME}/.local/share/mise",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=rustup,target="${HOME}/.local/share/rustup",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=cargo,target="${HOME}/.local/share/cargo",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=krew,target="${HOME}/.local/share/krew",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=helm,target="${HOME}/.local/share/helm",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    MISE_ALWAYS_KEEP_DOWNLOAD=true \
    .local/share/chezmoi/install.sh --data=false \
    && .local/bin/check-dotfiles \
    && echo "Cache bust: $CACHE_BUST"

FROM setup
ARG CACHE_BUST
ARG USER
ARG UID

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=apt-lib,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && .local/bin/check-dotfiles \
    && echo "Cache bust: $CACHE_BUST"
