#!/bin/sh

pkill swtpm

if test -n "$DBUS_SESSION_BUS_PID"; then
    kill "$DBUS_SESSION_BUS_PID"
fi

dbus-uuidgen --ensure
eval `dbus-launch --sh-syntax`
export XDG_CONFIG_HOME=$HOME/.config
/usr/share/swtpm/swtpm-create-user-config-files --root
mkdir -p ${XDG_CONFIG_HOME}/mytpm1
swtpm_setup --tpm2 --tpmstate $XDG_CONFIG_HOME/mytpm1 --createek --decryption --create-ek-cert --create-platform-cert --lock-nvram --overwrite --display
swtpm socket --tpm2 --tpmstate dir=$XDG_CONFIG_HOME/mytpm1 --flags startup-clear --ctrl type=tcp,port=2322 --server type=tcp,port=2321 --daemon
tpm2-abrmd --logger=stdout --tcti=swtpm: --session --allow-root --flush-all &
export TPM2TOOLS_TCTI="tabrmd:bus_type=session"
export TCTI=$TPM2TOOLS_TCTI
