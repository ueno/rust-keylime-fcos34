# Testing rust-keylime on Fedora CoreOS VM

This note summarizes how to install [rust-keylime] on Fedora CoreOS VM
and test it with other Keylime components running in a container on
the host.  Work in progress.

## Setup

- `keylime_agent` from [rust-keylime] runs on a Fedora 34 CoreOS VM.
  The service listens on 192.168.127.2:9002.

- `keylime_verifier` and `keylime_registrar` from Python Keylime runs
  on a Fedora 34 based container.  Those services listen on
  192.168.128.1:*.

## Steps

### Preparation on the host

1. Set up private networks for containerized services
   (`keylime_verifier` and `keylime_registrar`) and the VM. This step
   is necessary for the VM guest to see the services on the host
   through [gvisor-tap-vsock] launched by `podman machine`

```console
$ sudo ip addr add 192.168.127.1/255.255.255.0 dev lo
$ sudo ip addr add 192.168.128.1/255.255.255.0 dev lo
```

2. Create a Fedora CoreOS VM for running the Rust agent

```console
$ podman machine init fcos34
$ podman machine start fcos34
$ podman machine ssh fcos34
```

(in the VM session)

```console
$ git clone https://github.com/ueno/rust-keylime-fcos34
$ sudo rpm-ostree install swtpm swtpm-tools https://download.copr.fedorainfracloud.org/results/ueno/rust-keylime/fedora-34-x86_64/02690049-rust-keylime_agent/keylime_agent-0.1.0~20210912g6aa43983-1.fc34.x86_64.rpm
$ sudo systemctl reboot
```

3. Set up port forwarding between the host and the VM.

```console
$ curl http://0.0.0.0:7777/services/forwarder/expose \
       -X POST -d '{"local":":9002","remote":"192.168.127.2:9002"}'
```

4. Create a container for running the rest of components

```console
$ podman build -t keylime-no-agent:latest container
```

### Running `keylime_verifier` and `keylime_registrar` in the container

1. Run the container

```console
$ podman run -ti -p 8890:8890 -p 8891:8891 -p 8881:8881 -p 8992:8992 \
             localhost/keylime-no-agent:latest
```

2. Run swtpm

```console
# . setup_swtpm.sh
```

3. Run the `keylime_verifier` and `keylime_registrar` services in background

```console
$ keylime_verifier &
$ keylime_registrar &
```

### Running `keylime_agent` on the VM

1. SSH to the VM and start a root session

```console
$ podman machine ssh fcos34
$ sudo -i
```

2. Set up IMA policy

```console
# cat ~core/rust-keylime-fcos34/ima-policies/ima-policy-keylime \
      > /sys/kernel/security/ima/policy
```

3. Run swtpm

```console
# . ~core/rust-keylime-fcos34/container/setup_swtpm.sh
```

4. Run `keylime_ima_emulator` in background

```console
# keylime_ima_emulator &
```

5. Run `keylime_agent` (listening on 0.0.0.0 instead of 127.0.0.1)

```console
# cp ~core/rust-keylime-fcos34/keylime.conf .
# sed -i -e '/cloudagent_ip = /s/127\.0\.0\.1/0.0.0.0/' \
         -e '/registrar_ip = /s/127\.0\.0\.1/192.168.128.1/' keylime.conf
# RUST_LOG=keylime_agent=trace KEYLIME_CONFIG=$PWD/keylime.conf keylime_agent
```

### Access the agent through `keylime_tenant`

1. Run `keylime_tenant` to register the agent

(in the container)

```console
$ keylime_tenant -v 192.168.128.1 -t 192.168.127.2 \
                 -u d432fbb3-d2f1-4a97-9ef7-75bd81c00000 -c status
$ echo test > somefile
$ keylime_tenant -v 192.168.128.1 -t 192.168.127.2 \
                 -u d432fbb3-d2f1-4a97-9ef7-75bd81c00000 -f somefile -c add
```

## Disclaimer

The files in `ima-policies` and `keylime.conf` are copied from the
official [keylime] repository.  The same license (ASL-2.0) applies to
those files.

[gvisor-tap-vsock]: https://github.com/containers/gvisor-tap-vsock
[rust-keylime]: https://github.com/keylime/rust-keylime
[keylime]: https://github.com/keylime/keylime
