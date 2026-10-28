# Local example

Applies circuit-podman to a throwaway Rocky Linux 10 container with systemd. You need Conn3x and Podman.

Podman runs containers of its own inside it, so the host container runs privileged, which is simplest with rootful Podman. On a Mac, use the Podman machine's root connection. On Linux, use `sudo podman`:

```sh
export CONTAINER_CONNECTION=podman-machine-default-root   # macOS
export PODMAN="sudo podman"                               # Linux
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To look at the result:

```sh
ssh -p 2222 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 systemctl status whoami
```

The `whoami` container answers on port 8080 inside the host, and prints `Name: from-the-env-file`, which it read from its secrets file. Apply with `-var whoami_name=something-else` and only that container restarts.

Running Podman inside a container needs two tweaks that a real host doesn't. `up.sh` keeps `/var/lib/containers` on a volume, so the inner Podman can use overlayfs, and moves the inner Podman's network to `10.89.0.0/16`, so it doesn't clash with the outer one's `10.88.0.0/16`.

`up.sh` listens on `127.0.0.1:2222`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
