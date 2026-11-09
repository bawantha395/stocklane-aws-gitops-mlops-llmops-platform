# kubernetes/

Kustomize for the app, Argo CD (app-of-apps) for everything else.

```text
argocd/
  project.yaml            AppProject: allowed repositories and namespaces
  root.yaml               stocklane-root, the only thing the bootstrap applies
  apps/                   platform.yaml · monitoring.yaml · workload.yaml
base/                     infrastructure (secrets, database job, policy, ingress) + 4 services
environments/dev/         namespace, configmap.yaml, image pins, ingress patch, Helm values/
platform/                 StorageClass, ClusterSecretStore
monitoring/               Grafana secret, ServiceMonitors, rules, dashboard
admin/                    admin ALB ingress (written by the Deploy workflow)
```

Third-party software is installed from pinned Helm charts by Argo CD; its settings are the
small files in `environments/dev/values/`. Nothing is vendored.

`environments/dev/configmap.yaml`, `ingress-patch.yaml`, `values/alb-controller.yaml`, the `images:` block,
`release.json` and `admin/ingress.yaml` are written by the Deploy workflow (plain shell and heredocs
in `deploy.yml`). Do not edit them by hand.

Local checks:

```bash
kustomize build kubernetes/environments/dev | kubeconform -strict -ignore-missing-schemas -summary -
```
