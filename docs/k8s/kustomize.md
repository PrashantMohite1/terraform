
---

## Kustomize Deep Dive

### What It Is
A tool to customize Kubernetes YAMLs **without templates**. It uses a **Base + Overlay** pattern.
- **No Templating**: Files are valid, standard Kubernetes YAML. No `{{ variables }}`.
- **Native**: Built directly into `kubectl` (`kubectl kustomize`).

### Core Concepts
1.  **Base**: The common configuration shared by all environments.
    - Contains `deployment.yaml`, `service.yaml`, etc.
    - Defined by a `kustomization.yaml` listing resources.
2.  **Overlay**: Environment-specific modifications.
    - References the `base`.
    - Contains **Patches** (small YAML files changing specific fields like `replicas` or `resources`).
    - Can override image tags or add ConfigMaps.

### Directory Structure
```text
kustomize/
├── base/
│   ├── kustomization.yaml   # Lists resources
│   ├── deployment.yaml      # Common definition
│   └── service.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml # References base + patches
    │   └── patch-replicas.yaml # Sets replicas: 1
    └── prod/
        ├── kustomization.yaml
        └── patch-resources.yaml # Sets high CPU/RAM limits
```

### Example Overlay (`overlays/dev/kustomization.yaml`)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
patches:
  - path: patch-replicas.yaml
```

### Why Use It?
- **Single Source of Truth**: Update `base` once, changes propagate to all environments.
- **No Duplication**: No need to copy entire folders for `dev`, `staging`, `prod`.
- **Safety**: Reduces configuration drift; patches are explicit and small.

---

## How kustomize and skaffold Work Together

### The Workflow
1.  **Skaffold Build**: Builds image `my-app:git-abc123`.
2.  **Kustomize Render**: Skaffold runs `kustomize build` on the specified overlay path.
    - Merges `base` + `patches`.
    - Generates a final raw YAML.
3.  **Image Injection**: Skaffold intercepts the generated YAML and replaces the image name `my-app` with `my-app:git-abc123`.
4.  **Deploy**: Skaffold runs `kubectl apply` with the final, injected YAML.

### Visual Flow
```text
[ Source Code ] --> [ Skaffold ] --> [ Docker Build ] --> [ Image: app:tag123 ]
                                                              |
[ K8s Base ] + [ Patches ] --> [ Kustomize ] --> [ Raw YAML ] |
                                                              v
                                                    [ Inject Tag ] --> [ kubectl apply ] --> [ PODS RUNNING ]
```

---
