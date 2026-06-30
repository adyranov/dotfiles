# syntax=docker/dockerfile:1.25@sha256:0adf442eae370b6087e08edc7c50b552d80ddf261576f4ebd6421006b2461f12

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM fedora:44@sha256:6c75d5bf57cb0fa5aa4b92c6a83c86c791644496d9ac230de7711f5b8ec3b898 AS base
ARG USER
ARG UID

# hadolint ignore=DL3040,DL3041
RUN --mount=type=secret,id=CUSTOM_CA,dst=/run/secrets/custom_ca.pem,required=false \
    --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,id=dnf-lib,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    set -eux \
    && if [ -s /run/secrets/custom_ca.pem ]; then install -m 0644 /run/secrets/custom_ca.pem /etc/pki/ca-trust/source/anchors/custom-ca.pem && update-ca-trust; fi \
    && dnf -y upgrade --refresh \
    && dnf -y install --setopt=install_weak_deps=False \
        ca-certificates \
        curl \
        dnf-plugins-core \
        git \
        glibc-langpack-en \
        sudo \
        tar \
        unzip \
        util-linux \
        wget \
        which \
        zsh \
    && groupadd --gid "$UID" "$USER" \
    && useradd -m -s /usr/bin/zsh --uid "$UID" --gid "$USER" "$USER" \
    && mkdir -p /etc/sudoers.d \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER" \
    && chmod 0440 "/etc/sudoers.d/$USER" \
    && printf '%s\n' \
        '#%PAM-1.0' \
        'auth       sufficient   pam_permit.so' \
        'account    sufficient   pam_permit.so' \
        'session    sufficient   pam_permit.so' \
        > /etc/pam.d/sudo \
    && chown -R "$USER:$USER" "/home/$USER"

FROM base AS setup
ARG USER
ARG UID

ENV HOME=/home/$USER
ENV LANG=en_US.UTF-8
WORKDIR $HOME
COPY --chown=$USER:$USER . .local/share/chezmoi
USER $USER
CMD ["/usr/bin/zsh"]

FROM setup AS test
ARG CACHE_BUST
ARG USER
ARG UID

RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,id=dnf-lib,target=/var/lib/dnf,sharing=locked \
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

RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,id=dnf-lib,target=/var/lib/dnf,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && .local/bin/check-dotfiles \
    && echo "Cache bust: $CACHE_BUST"
