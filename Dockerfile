FROM alpine:latest

ARG CONTAINER_USER=devcontainer

ENV HOME=/home/$CONTAINER_USER

WORKDIR $HOME

COPY . .local/share/chezmoi

RUN set -eux; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/main" > /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
  && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  ; \
	apk add --update \
		bash \
    curl \
    gnupg \
    ncurses \
    sudo \
    tzdata \
		wget \
    zsh \
  ; \
  rm -rf /var/cache/apk/* \
  ; \
  adduser -u 54321 -s /bin/zsh -D $CONTAINER_USER \
    && echo "$CONTAINER_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$CONTAINER_USER \
    && chmod 0440 /etc/sudoers.d/$CONTAINER_USER \
  ; \
  chown -R $CONTAINER_USER:$CONTAINER_USER $HOME

USER $CONTAINER_USER

RUN .local/share/chezmoi/install.sh

CMD /bin/zsh
