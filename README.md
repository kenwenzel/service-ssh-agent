# SSH Agent Docker image

The exposed ssh-agent socket will be accessible to all users (not only root) in any container.  
This is achieved by exposing a proxy socket (`/.ssh-agent/proxy-socket`) via socat.

## Usage

### 1. Start the ssh-agent container 

```bash
docker run -d --name=ssh-agent kenwenzel/ssh-agent
```

### 2. Add your ssh keys

Replace `~/.ssh` with the path to your keys and `id_rsa` with the key name.  
If the key has a passphrase, you will be asked to enter it.

```bash
docker run --rm --volumes-from=ssh-agent -v ~/.ssh:/root/.ssh -it kenwenzel/ssh-agent ssh-add /root/.ssh/id_rsa
```

### 3. Access SSH keys from the ssh-agent in other containers

Mount the ssh-agent socket and set the `SSH_AUTH_SOCK` variable in other containers.

Docker

```bash
docker run --rm --volumes-from=ssh-agent -e SSH_AUTH_SOCK=/.ssh-agent/proxy-socket -it <image> ssh-add -l
```

Docker Compose

```yaml
  ...
  volumes_from:
    - ssh-agent
  ...
  environment:
    - SSH_AUTH_SOCK /.ssh-agent/proxy-socket
  ...
```

### Deleting all keys from the ssh-agent

```bash
docker run --rm --volumes-from=ssh-agent -it kenwenzel/ssh-agent ssh-add -D
```
