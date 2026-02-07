# The Unlicense
#
# This is free and unencumbered software released into the public domain.
# Anyone is free to copy, modify, distribute, and perform the software, as well as
# to sublicense it, all without any conditions whatsoever.
#
# See the full text of the Unlicense at: https://unlicense.org/

FROM ghcr.io/bbhtt/fdsdk-build-env-base:latest

RUN pacman-key --init && pacman --noconfirm -Syyuu

ARG user=user

RUN mkdir -p /usr/libexec/git-core/ \
	&& ln -s /usr/lib/git-core/git-credential-libsecret /usr/libexec/git-core/git-credential-libsecret

RUN useradd -r -md /home/${user} -s /bin/zsh --uid 1010 ${user} \
	&& echo "%${user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
	&& mkdir -p /home/${user}/build-root

COPY --chown=${user}:${user} . /home/${user}/build-root

USER ${user}

RUN cd /home/${user}/build-root && ./makepkg.sh

RUN sudo install -Dm0755 /home/${user}/build-root/abicheck.sh /usr/bin/abicheck

RUN sudo pip install --break-system-packages --no-deps \
    git+https://gitlab.com/BuildStream/infrastructure/gitlab-merge-request-generator.git@35e8292793d2712c11f24c48fc056a2597166305 \
    git+https://gitlab.com/CodethinkLabs/lorry/bst-to-lorry.git@028afcd3b7d9640bebb1bb9855ec6d3d9797a1ff \
    "git+https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git@$(git ls-remote --tags https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git | awk -F/ '{print $3}' | sed 's/\^{}$//' | sort -V | tail -n1)#subdirectory=bst-single-updater" \
    "git+https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git@$(git ls-remote --tags https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git | awk -F/ '{print $3}' | sed 's/\^{}$//' | sort -V | tail -n1)#subdirectory=lorry-mirror-updater" \
    "git+https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git@$(git ls-remote --tags https://gitlab.com/freedesktop-sdk/freedesktop-sdk-utils.git | awk -F/ '{print $3}' | sed 's/\^{}$//' | sort -V | tail -n1)#subdirectory=nvd-database-downloader"

RUN sudo pacman --noconfirm -Rdd python-click
RUN sudo pip install --break-system-packages click==8.2.1 libversion==1.2.4

RUN sudo pacman --noconfirm -Syyuu \
    && pacman -Q | grep "\-debug" | cut -d ' ' -f 1 | xargs -r sudo pacman -Rs --noconfirm \
	&& sudo pacman -Scc --noconfirm \
	&& sudo rm -rf /tmp/* \
	&& sudo sed -i "/^%${user} ALL=(ALL) NOPASSWD: ALL$/d" /etc/sudoers \
	&& sudo rm -rf /home/${user}/ \
	&& sudo userdel -r -f ${user} || true

ENV PYTHONWARNINGS="ignore::UserWarning"
