# syntax=docker/dockerfile:1.29@sha256:572cebbc2b15e6f84c077742952674889cb63cd5e9b80abdffcbe587b6f19183

ARG CACHE_BUST=1
ARG USER=devcontainer
ARG UID=54321

FROM fedora:44@sha256:15da97ed9aa94dd3d92c3925eb89520f6c80e07ea7ee24cba848d1f8b6912b3e AS base
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
        chezmoi \
        curl \
        dnf-plugins-core \
        git \
        glibc-langpack-en \
        libatomic \
        sudo \
        tar \
        unzip \
        util-linux \
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
ARG WITHOUT_TOOLCHAINS=true

RUN --mount=type=secret,id=GIT_AUTH_TOKEN,dst=/run/secrets/github_token,uid=$UID,required=false \
    --mount=type=cache,id=dnf-cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,id=dnf-lib,target=/var/lib/dnf,sharing=locked \
    --mount=type=cache,id=mise,target="${HOME}/.local/share/mise",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=rustup,target="${HOME}/.local/share/rustup",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=cargo,target="${HOME}/.local/share/cargo",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=cache,id=helm,target="${HOME}/.local/share/helm",uid=${UID},gid=${UID},sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    --mount=type=tmpfs,target=/tmp \
    GITHUB_TOKEN="$( [ -f /run/secrets/github_token ] && cat /run/secrets/github_token || true )" \
    && CI=true \
    && export CI GITHUB_TOKEN \
    && WITHOUT_TOOLCHAINS="$WITHOUT_TOOLCHAINS" .local/share/chezmoi/install.sh --data=false \
    && zsh -lic 'mise trust ~/.local/share/chezmoi && mise -C ~/.local/share/chezmoi run test' \
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
    GITHUB_TOKEN=$([ -f /run/secrets/github_token ] && cat /run/secrets/github_token || true) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && echo "Cache bust: $CACHE_BUST"
