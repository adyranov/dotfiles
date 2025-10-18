# syntax=docker/dockerfile:1.19

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM adyranov/archlinux AS base
ARG USER
ARG UID

RUN --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    set -eux \
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

CMD ["/usr/bin/zsh"]

FROM base AS test
ARG CACHE_BUST
ARG USER
ARG UID

ENV HOME=/home/$USER
WORKDIR $HOME
COPY --chown=$USER:$USER . .local/share/chezmoi
USER $USER

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

CMD ["/usr/bin/zsh"]

FROM base
ARG CACHE_BUST
ARG USER
ARG UID

ENV HOME=/home/$USER
WORKDIR $HOME
COPY --chown=$USER:$USER . .local/share/chezmoi
USER $USER

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=pacman-pkg,target=/var/cache/pacman/pkg,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && .local/bin/check-dotfiles \
    && echo "Cache bust: $CACHE_BUST"

CMD ["/usr/bin/zsh"]
