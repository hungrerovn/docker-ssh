#!/bin/sh
set -eu

DISK_SIZE="${DISK_SIZE:-16G}"
MEM="${MEM:-512}"
CPUS="${CPUS:-1}"
SSH_PORT="${SSH_PORT:-2026}"
SSH_BIND="${SSH_BIND:-0.0.0.0}"
PREALLOC="${PREALLOC:-0}"
MITIGATIONS_OFF="${MITIGATIONS_OFF:-1}"

grow_disk() {
  img="$1"
  before=$(stat -c %s "$img")
  truncate -s ">$DISK_SIZE" "$img"
  after=$(stat -c %s "$img")
  if [ "$before" != "$after" ]; then
    e2fsck -fy "$img" || true
    if ! resize2fs "$img"; then
      truncate -s "$before" "$img"
      echo "[-] resize2fs error" >&2
      exit 1
    fi
  fi
  tune2fs -m 0 "$img" || true
}

grow_disk "$ROOTFS"

MACHINE="microvm"
if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  ACCEL="kvm"
  CPU="host"
  if qemu-system-x86_64 -M microvm,help 2>/dev/null | grep -q 'pit='; then
    MACHINE="microvm,pit=off,pic=off,rtc=off"
  fi
  echo "[+] KVM, $CPUS vCPU"
else
  ACCEL="tcg,thread=multi,tb-size=256"
  CPU="max"
  echo "[-] no KVM -> TCG, $CPUS vCPU"
fi

APPEND="console=ttyS0 reboot=k panic=1 pci=off root=/dev/vda rw tsc=reliable"
[ "$MITIGATIONS_OFF" = 1 ] && APPEND="$APPEND mitigations=off"

MEMOPT=""
if [ "$PREALLOC" = 1 ]; then
  MEMOPT="-object memory-backend-ram,id=mem,size=${MEM}M,prealloc=on -machine memory-backend=mem"
fi

echo "[+] ssh -p $SSH_PORT debian@127.0.0.1 (pw: debian)"
exec qemu-system-x86_64 \
  -M "$MACHINE" -accel "$ACCEL" -cpu "$CPU" -m "$MEM" -smp "$CPUS" $MEMOPT \
  -nodefaults -no-user-config -nographic -serial mon:stdio -no-reboot \
  -kernel "$KERNEL" -append "$APPEND" \
  -drive id=rootfs,file="$ROOTFS",format=raw,if=none,cache=unsafe,aio=threads,discard=unmap \
  -device virtio-blk-device,drive=rootfs \
  -netdev "user,id=n0,ipv6=off,hostfwd=tcp:${SSH_BIND}:${SSH_PORT}-:22" \
  -device virtio-net-device,netdev=n0
