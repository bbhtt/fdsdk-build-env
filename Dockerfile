FROM archlinux:latest

LABEL org.opencontainers.image.authors="bbhtt <bbhtt.zn0i8@slmail.me>"
LABEL org.opencontainers.image.title="Freedesktop SDK Build Environment"
LABEL org.opencontainers.image.source="https://github.com/bbhtt/buildstream-aur-packages"

ARG user=user

RUN echo -e "keyserver-options auto-key-retrieve" >> /etc/pacman.d/gnupg/gpg.conf && \
	sed -i '/CheckSpace/s/^/#/g' /etc/pacman.conf && \
	sed -i '/OPTIONS/s/debug/!debug/g' /etc/makepkg.conf && \
	pacman-key --init && pacman --noconfirm -Syyuu

RUN pacman --noconfirm -S base base-devel bat desktop-file-utils \
	diffoscope diffutils wl-clipboard eza flatpak-builder git-delta \
	micro qemu-base starship swtpm time traceroute trash-cli tree wget \
	zsh inetutils fzf python-pip python-virtualenv python-gitlab ruff \
	python-pylint python-ruamel-yaml libabigail openssh gnupg

RUN mkdir -p /usr/libexec/git-core/ \
	&& ln -s /usr/lib/git-core/git-credential-libsecret /usr/libexec/git-core/git-credential-libsecret

RUN useradd -r -md /home/${user} -s /bin/bash --uid 1010 ${user} \
	&& echo "%${user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
	&& mkdir -p /home/${user}/build-root

COPY --chown=${user}:${user} . /home/${user}/build-root

USER ${user}
RUN curl -s -o /home/${user}/zshrc https://raw.githubusercontent.com/bbhtt/dotfiles/refs/heads/main/zshrc
RUN touch /home/${user}/.zshrc
RUN printf "echo 'A zsh config provided at ~/zshrc, move it to ~/.zshrc to have effect'\n" >> /home/${user}/.zshrc
RUN sudo chsh -s $(which zsh)
RUN cd /home/${user}/build-root && ./makepkg.sh || true


RUN sudo pacman --noconfirm -Syyuu \
	&& sudo pacman -Rs --noconfirm "$(pacman -Q|grep "\-debug"|cut -d ' ' -f 1|xargs)" || true \
	&& sudo pacman -Scc --noconfirm \
	&& sudo rm -rf /tmp/* \
	&& sudo rm -rf /home/${user}/build-root

WORKDIR  /home/${user}
