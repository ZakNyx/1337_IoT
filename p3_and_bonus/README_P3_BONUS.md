# Inception-of-Things — Part 3 + Bonus Setup Guide

## Prerequisites

- Ubuntu VM (8GB+ RAM recommended, 6GB minimum)
- Internet access

---

## Part 3: K3d + Argo CD

### 1. Install dependencies

```bash
# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# LOG OUT AND BACK IN after this

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# K3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Argo CD CLI
sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo chmod +x /usr/local/bin/argocd
```

> **Note (macOS ARM):** Replace the argocd download URL with:
> `https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-arm64`
>
> **Note (macOS sed):** On macOS, `sed -i` requires `sed -i ''` (empty extension argument).

---

### 2. Create the K3d cluster

```bash
k3d cluster create iot \
  -p "8888:8888@loadbalancer" \
  --wait
```

Verify:

```bash
kubectl get nodes
```

---

### 3. Create namespaces

```bash
kubectl create namespace argocd
kubectl create namespace dev
```

---

### 4. Install Argo CD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

Get the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

Access the UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

Open `https://localhost:8080` → login with `admin` + password from above.

---

### 5. Create a public GitHub repo

Repo name must contain a team member's login (e.g., `yourlogin-iot`).

Inside the repo, create a `manifests/` folder with two files:

**manifests/deployment.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
        - name: wil-playground
          image: wil42/playground:v1
          ports:
            - containerPort: 8888
```

**manifests/service.yaml:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: wil-playground
  ports:
    - port: 8888
      targetPort: 8888
```

Push:

```bash
git add . && git commit -m "feat: add k8s manifests v1" && git push
```

---

### 6. Create the Argo CD Application

Create `p3/confs/argocd-app.yaml` (replace repo URL with yours):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil-playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOURLOGIN/YOURLOGIN-iot.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

Apply:

```bash
kubectl apply -f p3/confs/argocd-app.yaml
```

---

### 7. Verify v1

```bash
kubectl get pods -n dev
kubectl port-forward svc/wil-playground -n dev 8888:8888 &
sleep 2
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v1"}
```

---

### 8. Demo v1 → v2 switch

In your GitHub repo:

```bash
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git add . && git commit -m "chore: update to v2" && git push
```

Wait ~3 minutes for auto-sync (or force it):

```bash
argocd app sync wil-playground --server localhost:8080 --insecure
```

Restart port-forward (pod was recreated):

```bash
kubectl port-forward svc/wil-playground -n dev 8888:8888 &
sleep 2
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v2"}
```

**Part 3 is complete.**

---

---

## Bonus: Local GitLab replacing GitHub

### 1. Delete and recreate the cluster with more ports

```bash
k3d cluster delete iot
k3d cluster create iot \
  -p "8888:8888@loadbalancer" \
  -p "8443:443@loadbalancer" \
  -p "9090:80@loadbalancer" \
  --agents 1 \
  --wait
```

---

### 2. Create namespaces

```bash
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab
```

---

### 3. Install Argo CD

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  --server-side --force-conflicts

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

Note the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo
```

---

### 4. Deploy GitLab CE (lightweight single container)

Create `bonus/confs/gitlab-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab
  namespace: gitlab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab
  template:
    metadata:
      labels:
        app: gitlab
    spec:
      containers:
        - name: gitlab
          image: gitlab/gitlab-ce:latest
          ports:
            - containerPort: 80
              name: http
            - containerPort: 22
              name: ssh
          env:
            - name: GITLAB_OMNIBUS_CONFIG
              value: |
                external_url 'http://gitlab.gitlab.svc.cluster.local'
                gitlab_rails['initial_root_password'] = 'P@ssw0rd123!'
                puma['worker_processes'] = 0
                sidekiq['max_concurrency'] = 5
                prometheus_monitoring['enable'] = false
                gitlab_rails['env'] = { 'MALLOC_CONF' => 'dirty_decay_ms:1000,muzzy_decay_ms:1000' }
                gitaly['configuration'] = { concurrency: [{ rpc: '/gitaly.SmartHTTPService/PostReceivePack', max_per_repo: 3 }] }
          resources:
            requests:
              cpu: 200m
              memory: 2Gi
            limits:
              memory: 3Gi
          volumeMounts:
            - name: gitlab-data
              mountPath: /var/opt/gitlab
            - name: gitlab-config
              mountPath: /etc/gitlab
      volumes:
        - name: gitlab-data
          emptyDir: {}
        - name: gitlab-config
          emptyDir: {}
```

Create `bonus/confs/gitlab-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: gitlab
  namespace: gitlab
spec:
  selector:
    app: gitlab
  ports:
    - name: http
      port: 80
      targetPort: 80
    - name: ssh
      port: 22
      targetPort: 22
```

Apply:

```bash
kubectl apply -f bonus/confs/gitlab-deployment.yaml
kubectl apply -f bonus/confs/gitlab-service.yaml
```

Wait for GitLab to be ready (3–5 min):

```bash
kubectl wait --for=condition=Ready pods -l app=gitlab -n gitlab --timeout=600s
```

Then wait another ~2 minutes for GitLab internal initialization.

---

### 5. Access GitLab

```bash
kubectl port-forward svc/gitlab -n gitlab 9090:80 &
```

Open `http://localhost:9090` → login with `root` / `P@ssw0rd123!`

---

### 6. Create the GitLab project + push manifests

In GitLab UI: **New project → Create blank project → Name: `iot-app` → Public → Create**

Check what the default branch is (likely `main`).

```bash
cd /tmp && rm -rf iot-app && mkdir iot-app && cd iot-app
git init -b main

mkdir manifests

cat > manifests/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
        - name: wil-playground
          image: wil42/playground:v1
          ports:
            - containerPort: 8888
EOF

cat > manifests/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: wil-playground
  namespace: dev
spec:
  type: ClusterIP
  selector:
    app: wil-playground
  ports:
    - port: 8888
      targetPort: 8888
EOF

git add .
git commit -m "feat: add k8s manifests v1"
git remote add origin http://localhost:9090/root/iot-app.git
git push -u origin main
```

> When prompted: username = `root`, password = `P@ssw0rd123!`

---

### 7. Register repo in Argo CD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 2

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

argocd login localhost:8080 --insecure --username admin --password $ARGOCD_PASS

argocd repo add http://gitlab.gitlab.svc.cluster.local/root/iot-app.git \
  --username root \
  --password 'P@ssw0rd123!' \
  --insecure-skip-server-verification
```

---

### 8. Create the Argo CD Application

Create `bonus/confs/argocd-app-gitlab.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil-playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://gitlab.gitlab.svc.cluster.local/root/iot-app.git
    targetRevision: main
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

Apply:

```bash
kubectl apply -f bonus/confs/argocd-app-gitlab.yaml
sleep 10
kubectl get pods -n dev
```

---

### 9. Verify v1

```bash
kubectl port-forward svc/wil-playground -n dev 8888:8888 &
sleep 2
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v1"}
```

---

### 10. Demo v1 → v2 switch

```bash
cd /tmp/iot-app
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' manifests/deployment.yaml
git add . && git commit -m "chore: update to v2" && git push
```

Wait ~3 min for auto-sync or force it:

```bash
argocd app sync wil-playground --server localhost:8080 --insecure
```

Restart port-forward and verify:

```bash
kubectl port-forward svc/wil-playground -n dev 8888:8888 &
sleep 2
curl http://localhost:8888/
# Expected: {"status":"ok", "message": "v2"}
```

**Bonus is complete.**

---

## Useful commands

| Action | Command |
|---|---|
| Stop cluster | `k3d cluster stop iot` |
| Start cluster | `k3d cluster start iot` |
| Check all pods | `kubectl get pods -A` |
| Argo CD UI | `kubectl port-forward svc/argocd-server -n argocd 8080:443 &` → `https://localhost:8080` |
| GitLab UI | `kubectl port-forward svc/gitlab -n gitlab 9090:80 &` → `http://localhost:9090` |
| App endpoint | `kubectl port-forward svc/wil-playground -n dev 8888:8888 &` → `http://localhost:8888` |
| Force Argo sync | `argocd app sync wil-playground --server localhost:8080 --insecure` |
| Check Argo app | `argocd app get wil-playground --server localhost:8080 --insecure` |

## Repo structure

```
.
├── p3/
│   ├── scripts/
│   │   ├── install.sh
│   │   ├── setup.sh
│   │   └── deploy-argocd.sh
│   └── confs/
│       ├── argocd-namespace.yaml
│       ├── dev-namespace.yaml
│       └── argocd-app.yaml
└── bonus/
    ├── scripts/
    │   └── setup-all.sh
    └── confs/
        ├── gitlab-deployment.yaml
        ├── gitlab-service.yaml
        └── argocd-app-gitlab.yaml
```
