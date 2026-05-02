FROM ubuntu:24.04

# Required by systemd in Docker.
ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus dbus-user-session \
      ca-certificates curl git sudo jq gnupg build-essential \
      libnss-systemd rcm \
    && rm -rf /var/lib/apt/lists/*

# Mask units that do not make sense inside a container.
RUN systemctl mask \
      getty@tty1.service getty-static.service getty.target \
      console-getty.service \
      systemd-udevd.service \
      systemd-udevd-control.socket systemd-udevd-kernel.socket \
      sys-kernel-debug.mount sys-kernel-tracing.mount \
      dev-hugepages.mount dev-mqueue.mount \
      proc-sys-fs-binfmt_misc.automount proc-sys-fs-binfmt_misc.mount \
      systemd-remount-fs.service systemd-modules-load.service \
      systemd-tmpfiles-setup-dev.service 2>/dev/null || true

# Non-root user. Linger lets systemctl --user work without an active login session.
RUN useradd -m -s /bin/bash tester \
    && echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
    && mkdir -p /var/lib/systemd/linger \
    && touch /var/lib/systemd/linger/tester

# Mise is installed per-user; shims end up on PATH so the test steps can call
# mise-managed tools without sourcing any init script.
USER tester
WORKDIR /home/tester
RUN curl -fsSL https://mise.run | sh
ENV PATH="/home/tester/.local/bin:/home/tester/.local/share/mise/shims:${PATH}"

USER root
ENTRYPOINT ["/lib/systemd/systemd"]
