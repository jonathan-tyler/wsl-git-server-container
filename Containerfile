FROM registry.fedoraproject.org/fedora:42

RUN dnf -y upgrade \
    && dnf install -y \
    git \
    gitolite3 \
    hostname \
    openssh-server \
    procps-ng \
    systemd \
    shadow-utils \
    && dnf clean all

RUN useradd --create-home --home-dir /var/lib/gitolite --shell /bin/bash git \
    && passwd -d git \
    && mkdir -p /var/lib/gitolite/repositories /var/lib/gitolite/.ssh /var/lib/git-server /run/sshd \
    && chown -R git:git /var/lib/gitolite /var/lib/git-server \
    && chmod 0700 /var/lib/gitolite/.ssh \
    && git config --system init.defaultBranch main

COPY container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY container/sshd_config /etc/ssh/sshd_config

RUN chmod 0755 /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []