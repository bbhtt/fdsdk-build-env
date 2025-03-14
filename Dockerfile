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
    git+https://gitlab.com/BuildStream/infrastructure/gitlab-merge-request-generator.git@661579cd3e35651413016b796e54779e92478b13 \
    git+https://gitlab.com/CodethinkLabs/lorry/bst-to-lorry.git@f3a6a22fe09161e487bb57292cb25890350ce97e

RUN sudo pacman --noconfirm -Rdd python-dulwich
RUN sudo pip install --break-system-packages dulwich==0.22.1 libversion==1.2.4

RUN sudo pacman --noconfirm -Syyuu \
    && pacman -Q | grep "\-debug" | cut -d ' ' -f 1 | xargs -r sudo pacman -Rs --noconfirm \
	&& sudo pacman -Scc --noconfirm \
	&& sudo rm -rf /tmp/* \
	&& sudo sed -i "/^%${user} ALL=(ALL) NOPASSWD: ALL$/d" /etc/sudoers \
	&& sudo rm -rf /home/${user}/ \
	&& sudo userdel -r -f ${user} || true
