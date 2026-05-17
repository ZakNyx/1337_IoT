
---

# Inception-of-Things — Defense Preparation

## 1. What is Kubernetes (K8s)?

Kubernetes is a **container orchestration platform**. It automates deployment, scaling, and management of containerized applications. The subject itself says it's too complex to master in one project — you're getting a **minimal but real introduction**.

Key mental model: you describe **desired state** in YAML files, Kubernetes makes reality match that state and keeps it that way.

---

## 2. Core Kubernetes Concepts You Must Know

### Node
A machine (VM or physical) in the cluster. Two roles:
- **Control plane (master/server)** — manages the cluster, runs the API server, scheduler, controller manager
- **Worker (agent)** — runs your actual application pods

### Pod
The smallest deployable unit. Wraps one or more containers. Pods are **ephemeral** — they can die and be recreated.

### Deployment
Manages pods declaratively. You say "I want 3 replicas of this image" and the Deployment controller ensures that's always true. If a pod crashes, it recreates it.

```yaml
spec:
  replicas: 3        # Part 2: app2 requires this
  selector:
    matchLabels:
      app: my-app
```

### Service
Pods have dynamic IPs. A Service provides a **stable endpoint** to reach pods. Types:
- **ClusterIP** (default) — internal only, used in Part 3
- **NodePort** — exposes on a port on each node
- **LoadBalancer** — cloud provider external IP

### Namespace
Virtual cluster inside a cluster. Isolates resources. In Part 3 you create `argocd` and `dev`. In Bonus you add `gitlab`.

### Ingress
An HTTP router at the cluster edge. Routes requests to different services based on **hostname** or path. This is exactly what Part 2 tests:

| Host header | → Service |
|---|---|
| `app1.com` | → app1 service |
| `app2.com` | → app2 service |
| *(anything else)* | → app3 service (default) |

K3s ships with **Traefik** as its built-in Ingress controller.

### ConfigMap / Secret
External configuration injected into pods. Not directly tested but good to know.

---

## 3. K3s vs K3d — Critical Distinction

This is explicitly called out in Part 3: *"you must understand the difference between K3s and K3d"*.

| | K3s | K3d |
|---|---|---|
| **What it is** | Lightweight Kubernetes distribution | Tool to run K3s **inside Docker containers** |
| **Use case** | Real VMs, edge, embedded | Local dev, CI, testing |
| **How it runs** | Native process on the OS | K3s nodes are Docker containers |
| **Parts 1 & 2** | ✅ Used (in Vagrant VMs) | ❌ |
| **Part 3 & Bonus** | ❌ (no Vagrant) | ✅ Used |
| **RAM** | ~512MB | Depends on Docker |

Key phrase to say in defense: *"K3d is a wrapper that runs K3s clusters as Docker containers, so you get a full multi-node cluster on a single machine without needing Vagrant or multiple VMs."*

---

## 4. Part 1 — K3s and Vagrant

### What you built
Two VMs provisioned automatically by Vagrant:

| Machine | Hostname | IP | K3s role |
|---|---|---|---|
| Server | `<login>S` | 192.168.56.110 | **controller** (`k3s server`) |
| ServerWorker | `<login>SW` | 192.168.56.111 | **agent** (`k3s agent`) |

### What evaluators will check
- `kubectl get nodes` shows both nodes with status `Ready`
- The agent joined the server (requires the server's **node token**, typically read from `/var/lib/rancher/k3s/server/node-token`)
- SSH works on both with no password
- Interface IPs match the spec (use `ip a`, not `ifconfig`)

### What you must be able to explain
- How the agent joins: it uses the server's IP + node token
- Why `192.168.56.x` subnet: it's the VirtualBox host-only network
- The Vagrantfile `vm.network "private_network"` directive

---

## 5. Part 2 — K3s + Ingress Routing

### What you built
One VM, K3s server mode, 3 apps deployed via manifests, routed by hostname through Traefik Ingress.

### The Ingress resource you need to explain

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps-ingress
spec:
  rules:
  - host: app1.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-one
            port:
              number: 80
  - host: app2.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-two
            port:
              number: 80
  defaultBackend:           # catches everything else → app3
    service:
      name: app-three
      port:
        number: 80
```

### App2 has 3 replicas — why?
The subject shows it explicitly. In the Deployment: `replicas: 3`. This demonstrates **horizontal scaling** and **load balancing** via the Service.

### How to test
```bash
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110    # → app3 default
```

---

## 6. Part 3 — K3d + Argo CD (GitOps)

This is the most concept-heavy part.

### GitOps — the core concept
Instead of manually applying YAML, you push manifests to **Git**. Argo CD watches the repo and automatically syncs the cluster to match what's in Git. Git becomes the **single source of truth**.

Flow:
```
You edit deployment.yaml in GitHub
        ↓
Argo CD detects the diff (polls every ~3 min)
        ↓
Argo CD applies the change to the cluster
        ↓
New pod pulls updated image from Docker Hub
```

### Argo CD
A **GitOps continuous delivery tool** that runs inside the cluster. It:
- Watches a Git repo + path
- Compares cluster state vs repo state
- Applies differences automatically (`selfHeal: true`, `prune: true`)

### Key Argo CD concepts for defense

**Application resource** — the CRD that tells Argo CD what to watch:
```yaml
spec:
  source:
    repoURL: https://github.com/yourlogin/yourlogin-iot.git
    path: manifests        # folder inside the repo
    targetRevision: HEAD
  destination:
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true       # fix drift
      prune: true          # delete removed resources
```

**Sync status** — `Synced` means cluster matches Git. `OutOfSync` means there's a diff.

**Health status** — `Healthy` means pods are running correctly.

### The v1 → v2 demo
Evaluators will ask you to do this live:
```bash
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git add . && git commit -m "chore: update to v2" && git push
# wait ~3 min or force sync
argocd app sync wil-playground --server localhost:8080 --insecure
# restart port-forward, then:
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v2"}
```

---

## 7. Bonus — Local GitLab replacing GitHub

### What changes
Instead of GitHub (external), you run **GitLab CE inside the cluster** in the `gitlab` namespace. Argo CD points to the internal GitLab URL instead:

```
http://gitlab.gitlab.svc.cluster.local/root/iot-app.git
```

The `.svc.cluster.local` suffix is Kubernetes internal DNS — it resolves to the GitLab Service's ClusterIP.

### Why it's harder
- GitLab CE needs 2–3GB RAM minimum — the cluster must have `--agents 1` to have enough resources
- GitLab takes 3–5 min to start, then another ~2 min for internal init
- Argo CD needs `--insecure-skip-server-verification` because GitLab's internal TLS isn't trusted
- You must register the repo with `argocd repo add` before creating the Application

### What evaluators check
Same v1→v2 demo, but the git push goes to local GitLab, not GitHub.

---

## 8. Likely Defense Questions

**Q: What is the difference between a Pod and a Deployment?**
A Pod is a single instance of a running container, it's ephemeral. A Deployment manages the lifecycle of pods — it ensures the desired number are always running and handles updates/rollbacks.

**Q: Why do we need a Service if we have pods?**
Pods get random IPs that change when they're recreated. A Service provides a stable virtual IP and DNS name, and load-balances across all matching pods.

**Q: What is K3s?**
A lightweight, production-ready Kubernetes distribution by Rancher. It strips out non-essential features and bundles everything in a single binary (~70MB). Same API as full K8s.

**Q: What is K3d?**
A tool that runs K3s clusters as Docker containers. Each "node" is a container. Useful for local development — you get a real multi-node cluster without multiple VMs.

**Q: What does Argo CD's `selfHeal: true` do?**
If someone manually changes the cluster state (e.g., `kubectl edit deployment`), Argo CD detects the drift and reverts it back to what's in Git. Git always wins.

**Q: What is the `dev` namespace for?**
Isolation. It contains only the deployed application. Argo CD is in its own `argocd` namespace. Namespaces prevent resource name collisions and allow different RBAC policies per team/environment.

**Q: How does the agent join the server in Part 1?**
The agent needs the server's IP (`192.168.56.110`) and the node token from `/var/lib/rancher/k3s/server/node-token`. It runs `k3s agent --server https://192.168.56.110:6443 --token <token>`.

**Q: What port does the wil42/playground app use?**
Port `8888`. That's why the K3d cluster maps `-p "8888:8888@loadbalancer"`.

---

## 9. Quick Cheat Sheet — Commands You Must Know

```bash
# Cluster / nodes
kubectl get nodes
kubectl get nodes -o wide

# All resources in a namespace
kubectl get all -n dev
kubectl get pods -n argocd

# Namespaces
kubectl get ns
kubectl create namespace dev

# Apply manifests
kubectl apply -f file.yaml
kubectl apply -f ./directory/

# Argo CD
argocd app list --server localhost:8080 --insecure
argocd app get wil-playground --server localhost:8080 --insecure
argocd app sync wil-playground --server localhost:8080 --insecure

# Port forwarding (access services locally)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward svc/wil-playground -n dev 8888:8888 &

# Logs / describe
kubectl describe pod <name> -n dev
kubectl logs <pod-name> -n dev
```

---

The three things most likely to trip you up in the defense: being able to clearly explain **K3s vs K3d**, the **GitOps flow** (Git → Argo CD → cluster), and doing the **live v1→v2 switch** confidently.