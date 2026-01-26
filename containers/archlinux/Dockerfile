# syntax=docker/dockerfile:1.21@sha256:27f9262d43452075f3c410287a2c43f5ef1bf7ec2bb06e8c9eeb1b8d453087bc

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM adyranov/archlinux@sha256:4c5b62c5248dd92e882ac354b81976ec330dec0cee1ef6337d5279661cb969b5 AS base
ARG USER
ARG UID

RUN --mount=type=secret,id=CUSTOM_CA,dst=/run/secrets/custom_ca.pem,required=false \
    --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    set -eux \
    && if [ -s /run/secrets/custom_ca.pem ]; then install -m 0644 /run/secrets/custom_ca.pem /etc/ca-certificates/trust-source/anchors/custom-ca.pem && trust extract-compat; fi \
    && groupadd --gid "$UID" "$USER" \
    && useradd -s /bin/bash -u "$UID" --gid "$USER" -m "$USER" \
    && mkdir -p /etc/sudoers.d \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$USER" \
    && chmod 0440 "/etc/sudoers.d/$USER" \
    && chown -R "$USER:$USER" "$HOME" \
    && pacman -Sy --noconfirm --needed \
        bash \
        git \
        sudo \
        tar \
        unzip \
        wget \
        which \
        zsh \
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
    --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked \
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
    --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && .local/bin/check-dotfiles \
    && echo "Cache bust: $CACHE_BUST"
