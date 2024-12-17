## Usage

## Toolbox

### Create and enter

```bash
toolbox create FreedesktopSDK \
  -i ghcr.io/bbhtt/fdsdk-build-env:latest && \
toolbox enter FreedesktopSDK
```

### Stop and remove

```bash
toolbox rm -f FreedesktopSDK
```

### Update to latest image

Remove and recreate the container from the `latest` tag.

```bash
toolbox rm -f FreedesktopSDK && \
podman image pull ghcr.io/bbhtt/fdsdk-build-env:latest && \
toolbox create FreedesktopSDK -i ghcr.io/bbhtt/fdsdk-build-env:latest && \
toolbox enter FreedesktopSDK
```
