FROM opensuse:tumbleweed

RUN zypper dup -y && zypper install -y bash arch-install-scripts bubblewrap systemd-container zip python3-pip dosfstools e2fsprogs rsync which mkosi

# Install qemu-user-static for other architectures
RUN uname -m | grep aarch64 || zypper install -y qemu-linux-user

WORKDIR /build/

COPY . .

CMD ["/bin/sh", "./docker-entry.sh"]
