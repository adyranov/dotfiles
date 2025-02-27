# syntax=docker/dockerfile:1.14
FROM adyranov/archlinux

ARG USER=devcontainer
ARG UID=54321

ENV HOME=/home/$USER

WORKDIR $HOME

RUN pacman -Sy --noconfirm --needed \
    git \
    tar \
    sudo \
    unzip \
    wget \
    which \
    zsh  \
    && groupadd --gid $UID $USER \
    && useradd -s $(command -v zsh) -u $UID --gid $USER -m $USER \
    && echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER \
    && chmod 0440 /etc/sudoers.d/$USER \
    && chown -R $USER:$USER $HOME \
    && sudo rm -rf /var/cache/pacman/pkg/* /var/log/* /tmp/*


USER $USER

COPY --chown=$USER:$USER . .local/share/chezmoi

RUN --mount=type=secret,id=GITHUB_TOKEN,dst=/run/secrets/github_token,uid=$UID \
    GITHUB_ACCESS_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_API_TOKEN=$(cat /run/secrets/github_token) \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) \
    WITHOUT_TOOLCHAINS=true \
    .local/share/chezmoi/install.sh --data=false \
    && sudo rm -rf /var/cache/pacman/pkg/* /var/log/* /tmp/*

CMD /bin/zsh
