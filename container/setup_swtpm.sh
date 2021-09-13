#!/bin/sh

pkill swtpm

export XDG_CONFIG_HOME=$HOME/.config
/usr/share/swtpm/swtpm-create-user-config-files --root
mkdir -p ${XDG_CONFIG_HOME}/mytpm1
swtpm_setup --tpm2 --tpmstate $XDG_CONFIG_HOME/mytpm1 --createek --decryption --create-ek-cert --create-platform-cert --lock-nvram --overwrite --display
swtpm socket --tpm2 --tpmstate dir=$XDG_CONFIG_HOME/mytpm1 --flags startup-clear --ctrl type=tcp,port=2322 --server type=tcp,bindaddr=127.0.0.1,port=2321 --daemon
export TPM2TOOLS_TCTI="swtpm:port=2321"
export TCTI=$TPM2TOOLS_TCTI
