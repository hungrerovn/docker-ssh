FROM alpine:3.24

ARG KERNEL_URL="https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/20261118-6d7cfa9c6b53-0/x86_64/vmlinux-6.18.62"
ARG ROOTFS_URL="https://huggingface.co/hrv-clan/vm-disk/resolve/main/debian-rootfs.ext4"
ARG ROOTFS_SHA256="b2148a9e3a1c86746e0903c2733f94b3999f71618a54dc8f228ab8a29f60ac12"

RUN apk add --no-cache \
    qemu-system-x86_64 \
    e2fsprogs \
    curl \
    ca-certificates \
    coreutils \
    util-linux

RUN mkdir -p /opt/vm && \
    curl -fsSL -o /opt/vm/vmlinux-6.18.62 "$KERNEL_URL" && \
    curl -fsSL -o /opt/vm/debian-rootfs.ext4 "$ROOTFS_URL" && \
    echo "$ROOTFS_SHA256  /opt/vm/debian-rootfs.ext4" | sha256sum -c -

ENV VM_DIR=/opt/vm \
    KERNEL=/opt/vm/vmlinux-6.18.62 \
    ROOTFS=/opt/vm/debian-rootfs.ext4

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
