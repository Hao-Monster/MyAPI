#!/usr/bin/env bash
# Run as root via the Tokyo workflow, outside the ssh.service cgroup.
set -Eeuo pipefail
case ${1:-} in
  stage) ports=(22 28422) ;;
  finish) ports=(28422) ;;
  *) exit 2 ;;
esac
umask 022
socket_mode=false
if systemctl is-active --quiet ssh.socket || systemctl is-enabled --quiet ssh.socket; then
  socket_mode=true
fi
conf=/etc/ssh/sshd_config.d/60-ant-claude-ports.conf
socket=/etc/systemd/system/ssh.socket.d/99-ant-claude-ports.conf
stamp=/run/ant-claude-ssh-final
marker='# Managed by the Ant-Claude Tokyo workflow'
for path in "$conf" "$socket"; do
  if [[ -e $path ]] && ! grep -Fxq "$marker" "$path"; then
    echo "Unexpected existing configuration at $path" >&2
    exit 1
  fi
done
install -d -m 0755 /etc/ssh/sshd_config.d /run/sshd
/usr/sbin/sshd -t
if command -v ufw >/dev/null && LC_ALL=C ufw status | grep -Fxq 'Status: active'; then
  ufw allow proto tcp from 0.0.0.0/0 to any port 28422
fi
backup=$(mktemp -d /run/ant-claude-sshd-backup.XXXXXX)
[[ ! -f $conf ]] || cp -p "$conf" "$backup/sshd"
[[ ! -f $socket ]] || cp -p "$socket" "$backup/socket"
apply_listeners() {
  if "$socket_mode"; then
    systemctl daemon-reload
    systemctl stop ssh.service ssh.socket
    systemctl start ssh.socket
  else
    systemctl reload-or-restart ssh.service
  fi
}
rollback() {
  trap - ERR
  set +e
  if [[ -f $backup/sshd ]]; then cp -p "$backup/sshd" "$conf"; else rm -f -- "$conf"; fi
  if [[ -f $backup/socket ]]; then cp -p "$backup/socket" "$socket"; else rm -f -- "$socket"; fi
  apply_listeners
  exit 1
}
trap rollback ERR
rm -f -- "$stamp"
{ echo "$marker"; printf 'Port %s\n' "${ports[@]}"; } > "$conf"
/usr/sbin/sshd -t
actual=$(/usr/sbin/sshd -T | awk '$1 == "port" {print $2}' | sort -nu | xargs)
[[ $actual == "${ports[*]}" ]] || { echo "Conflicting sshd ports: $actual" >&2; false; }
if "$socket_mode"; then
  install -d -m 0755 /etc/systemd/system/ssh.socket.d
  {
    echo "$marker"
    echo '[Socket]'
    echo 'ListenStream='
    for port in "${ports[@]}"; do
      # Keep the existing dual-stack entry during staging. The new SSH rule is IPv4.
      if [[ $port == 22 ]]; then echo 'ListenStream=22'; else echo "ListenStream=0.0.0.0:$port"; fi
    done
  } > "$socket"
fi
apply_listeners
for port in "${ports[@]}"; do test -n "$(ss -Hltn "sport = :$port")"; done
if [[ $1 == finish ]]; then
  test -z "$(ss -Hltn 'sport = :22')"
  touch "$stamp"
fi
trap - ERR
rm -r -- "$backup"
