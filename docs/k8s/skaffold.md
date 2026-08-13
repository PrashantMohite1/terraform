


## Executive Summary
- **Skaffold**: An automation tool for the **build-deploy loop**. It watches code, builds container images, tags them, and deploys to Kubernetes. It handles the "heavy lifting" so you don't have to manually run `docker build` and `kubectl apply`.
- **Kustomize**: A configuration management tool. It customizes raw Kubernetes YAML files for different environments (Dev, Prod) **without templating**. It merges a "Base" configuration with environment-specific "Overlays".
- **Integration**: Skaffold uses Kustomize to generate the final deployment manifests, injecting the newly built image tags automatically.

---

## Skaffold Deep Dive

### What It Does
Skaffold orchestrates the following steps automatically:
1.  **Build**: Triggers Docker, Jib, or Kaniko to compile code and create images.
2.  **Tag**: Assigns unique tags (e.g., Git commit hash, SHA) to images.
3.  **Push**: Pushes images to a registry (or skips for local Minikube).
4.  **Deploy**: Updates Kubernetes manifests with new image tags and applies them.

### Key Commands
| Command | Description | Use Case |
| :--- | :--- | :--- |
| `skaffold run` | Builds, tags, deploys **once**, then exits. | CI/CD pipelines, initial setup. |
| `skaffold dev` | Runs continuously. Watches files, auto-rebuilds, streams logs. Cleans up on `Ctrl+C`. | Active local development. |
| `skaffold debug` | Like `dev`, but exposes debug ports for IDE attachment. | Debugging inside the cluster. |
| `skaffold delete` | Removes all resources deployed by the current config. | Cleanup. |

### How It Builds Images
- **Context**: Skaffold sends a folder (defined in `skaffold.yaml`) to the build engine.
- **Compilation**: If using a `Dockerfile`, compilation (e.g., `mvn clean package`, `pip install`) happens **inside** the Docker build process. You do **not** need to run build commands manually.
- **Optimization**:
  - **Java**: Uses **Jib** (no Dockerfile needed, builds layers directly from Maven/Gradle).
  - **Python/Node**: Uses standard Dockerfiles + **File Sync** (copies changed files directly to container without rebuilding).

### Configuration: `skaffold.yaml`
```yaml
apiVersion: skaffold/v3
kind: Config
metadata:
  name: my-app

# 1. BUILD SECTION
build:
  artifacts:
    - image: my-service-name
      context: ./src-folder       # Folder containing Dockerfile & code
      # sync:                     # Optional: For instant file copying (Python/Node)
      #   manual:
      #     - src: "**/*.py"
      #       dest: /app
  local:
    push: false                   # Critical for Minikube (uses local cache)

# 2. DEPLOY SECTION
deploy:
  # Option A: Raw YAML
  # kubectl:
  #   manifests:
  #     - k8s/*.yaml
  
  # Option B: Kustomize (Recommended)
  kustomize:
    paths:
      - kustomize/overlays/dev

# 3. PROFILES (Environment Switching)
profiles:
  - name: prod
    deploy:
      kustomize:
        paths:
          - kustomize/overlays/prod
