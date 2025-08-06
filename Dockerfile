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
RUN sudo install -Dm0755 /home/${user}/build-root/single-updater.py /usr/bin/single-updater

RUN sudo pip install --break-system-packages --no-deps \
    git+https://gitlab.com/BuildStream/infrastructure/gitlab-merge-request-generator.git@773c8be54af9a9dd175157f6f1e38c4b86f2bcab \
    git+https://gitlab.com/CodethinkLabs/lorry/bst-to-lorry.git@65512da95f7ea62156b4370332ef602dd9e4eb6e \
    git+https://github.com/bbhtt/lorry-mirror-updater.git@v0.1.4#egg=lorry_mirror_updater

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
