# Platform Lab — Roadmap

A learning platform built around EKS, the Argo suite, and a full observability stack.
Each step builds on the last — follow the order to avoid dependency pain.

---

## Step 1 — Tag VPC Subnets for EKS

**Why first:** The AWS Load Balancer Controller and EKS itself discover subnets via tags.
Without them, load balancer provisioning silently fails. This is a one-line change per subnet
but blocks everything downstream.

### Changes

**`terraform/catalog/modules/vpc/main.tf`**

Add the following tags to each subnet resource:

| Subnet type | Tag | Value |
|---|---|---|
| `aws_subnet.public` | `kubernetes.io/role/elb` | `"1"` |
| `aws_subnet.private_with_egress` | `kubernetes.io/role/internal-elb` | `"1"` |
| `aws_subnet.private` | *(no EKS tag needed)* | — |

Additionally, if you plan to use the cluster name at tag time (needed for Karpenter subnet
discovery), add:

```hcl
"kubernetes.io/cluster/${var.cluster_name}" = "shared"
```

To support this cleanly, add an optional `cluster_tags` variable to the VPC module — a
`map(string)` merged into each subnet's tags. That way the VPC module stays decoupled from
EKS specifics and the cluster name is passed in from the environment stack.

### Acceptance criteria
- `aws_subnet.public` has `kubernetes.io/role/elb = 1`
- `aws_subnet.private_with_egress` has `kubernetes.io/role/internal-elb = 1`
- Tags are visible in the AWS console after apply

---

## Step 2 — ECR Module

**Why early:** You need somewhere to push images before you can deploy anything. Build this
before writing application code so the registry exists when you need it.

### Module: `terraform/catalog/modules/ecr`

#### Resources
- `aws_ecr_repository` — one per service image
- `aws_ecr_lifecycle_policy` — keeps costs and clutter down
- `aws_ecr_repository_policy` — controls cross-account or cross-role access if needed

#### Key design decisions

**Lifecycle policy (apply to all repos):**
```json
{
"rules": [
{
"rulePriority": 1,
"description": "Keep last 10 tagged releases",
"selection": {
"tagStatus": "tagged",
"tagPatternList": ["v*"],
"countType": "imageCountMoreThan",
"countNumber": 10
},
"action": { "type": "expire" }
},
{
"rulePriority": 2,
"description": "Purge untagged images after 7 days",
"selection": {
"tagStatus": "untagged",
"countType": "sinceImagePushed",
"countUnit": "days",
"countNumber": 7
},
"action": { "type": "expire" }
}
]
}
```

**Variables:**
- `name` — repository name (e.g. `platform-lab/api`)
- `image_scanning_on_push` — bool, default `true`; enables ECR basic scanning at no cost
- `mutability` — `"MUTABLE"` for dev (allows overwriting tags like `latest`), `"IMMUTABLE"` for prod

**Outputs:**
- `repository_url` — passed to CI and Helm values
- `repository_arn` — used in IAM policies for push access

#### IAM for GitHub Actions push

Create a policy (in the OIDC module or alongside ECR) that grants the apply role:
```
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:InitiateLayerUpload
ecr:UploadLayerPart
ecr:CompleteLayerUpload
ecr:PutImage
```

Alternatively, create a dedicated `github-push` OIDC role scoped only to ECR push — keeps
the apply role from needing ECR permissions and separates the CI concern from the IaC concern.

#### Environment stack wiring

Create a `terraform/catalog/modules/ecr-repos` (or just instantiate `ecr` multiple times)
and add an `ecr` unit to the network stack or a new `platform` stack. Repositories to create
from the start:
- `platform-lab/receiver`
- `platform-lab/api`
- `platform-lab/worker`

### Acceptance criteria
- Repositories visible in ECR console
- `docker push` from a GitHub Actions workflow succeeds using OIDC credentials
- Untagged images expire automatically

---

## Step 3 — EKS Module + IRSA Helper

### Module: `terraform/catalog/modules/eks`

Wrap `terraform-aws-modules/eks/aws` (community module, don't reimplement it).
The wrapper standardises the opinionated defaults you want across environments.

#### Cluster configuration

```hcl
module "eks" {
source = "terraform-aws-modules/eks/aws"
version = "~> 20.0"

cluster_name = var.name
cluster_version = var.kubernetes_version # default "1.31"

# Endpoint access — private-only is more secure but requires VPN/bastion
# for local kubectl. Start with both enabled, lock down later.
cluster_endpoint_public_access = true
cluster_endpoint_private_access = true

vpc_id = var.vpc_id
subnet_ids = var.private_with_egress_subnet_ids # control plane ENIs go here

# Modern auth — avoids the aws-auth ConfigMap entirely
authentication_mode = "API"

enable_cluster_creator_admin_permissions = true
}
```

#### Managed add-ons

Configure as EKS managed add-ons (not Helm-installed) so AWS handles version compatibility:

| Add-on | Notes |
|---|---|
| `vpc-cni` | Set `ENABLE_PREFIX_DELEGATION=true` to increase pod density per node |
| `coredns` | No special config needed to start |
| `kube-proxy` | No special config needed |
| `aws-ebs-csi-driver` | Needs an IRSA role — create it in the module |
| `aws-efs-csi-driver` | Optional; add if you need `ReadWriteMany` volumes |

#### System node group

A small managed node group that runs before Karpenter is bootstrapped — Karpenter itself,
ArgoCD, and other system workloads land here initially.

```hcl
eks_managed_node_groups = {
system = {
instance_types = ["t3.medium"]
min_size = 2
max_size = 4
desired_size = 2

labels = {
"node.kubernetes.io/purpose" = "system"
}
taints = [{
key = "node.kubernetes.io/purpose"
value = "system"
effect = "NO_SCHEDULE"
}]
}
}
```

Tainting the system node group keeps application workloads off it. Karpenter-provisioned
nodes have no taint and accept general workloads.

#### Access entries

Add access entries for your IAM user/role and the GitHub apply role:

```hcl
access_entries = {
admin = {
principal_arn = "arn:aws:iam::ACCOUNT:role/github-apply-dev"
policy_associations = {
admin = {
policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
access_scope = { type = "cluster" }
}
}
}
}
```

#### Variables

- `name` — cluster name
- `kubernetes_version` — default `"1.31"`
- `vpc_id`
- `private_with_egress_subnet_ids` — where worker nodes and control plane ENIs are placed
- `public_subnet_ids` — passed to LBC for public load balancers
- `environment`

#### Outputs

- `cluster_name`
- `cluster_endpoint`
- `cluster_certificate_authority_data`
- `oidc_provider_arn` — needed by every IRSA role
- `oidc_provider_url`
- `node_security_group_id`
- `cluster_security_group_id`

---

### Module: `terraform/catalog/modules/irsa`

A thin reusable wrapper so you're not copy-pasting the trust policy for every service account.

#### What it creates
- `aws_iam_role` with an OIDC trust policy scoped to a specific namespace + service account
- `aws_iam_role_policy_attachment` for each policy ARN provided

#### Variables
- `name` — role name
- `oidc_provider_arn`
- `oidc_provider_url`
- `namespace` — Kubernetes namespace of the service account
- `service_account` — Kubernetes service account name
- `policy_arns` — list of managed or inline policy ARNs to attach

#### Usage pattern (every component that touches AWS)
```hcl
module "lbc_irsa" {
source = "../../modules/irsa"

name = "${var.name}-aws-load-balancer-controller"
oidc_provider_arn = var.oidc_provider_arn
oidc_provider_url = var.oidc_provider_url
namespace = "kube-system"
service_account = "aws-load-balancer-controller"
policy_arns = [aws_iam_policy.lbc.arn]
}
```

### Acceptance criteria
- `kubectl get nodes` shows 2 system nodes
- `kubectl get pods -A` shows core add-ons running
- EBS CSI driver can provision a `PersistentVolumeClaim`
- GitHub apply role can authenticate with `kubectl` via OIDC

---

## Step 4 — Karpenter

Replace Cluster Autoscaler with Karpenter for all non-system workloads. Karpenter provisions
nodes directly via EC2 APIs, bin-packs more efficiently, handles Spot interruptions natively,
and is where the Kubernetes autoscaling ecosystem is heading.

### Module: `terraform/catalog/modules/karpenter`

#### AWS resources required

- **IRSA role** for the Karpenter controller (use the `irsa` module)
- Needs: `ec2:RunInstances`, `ec2:TerminateInstances`, `ec2:DescribeInstances`,
`iam:PassRole`, and several others — use the managed policy from the Karpenter docs
- **Node IAM role** — the role EC2 nodes launched by Karpenter will assume
- Attach: `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`,
`AmazonEKS_CNI_Policy`
- Register as an EKS access entry of type `EC2_LINUX` so nodes can join without aws-auth
- **SQS queue + EventBridge rules** — for Spot interruption and rebalance notifications
- Karpenter drains nodes gracefully before Spot reclamation using these events

#### Helm release (Terraform-managed bootstrap)

Karpenter must be installed before application workloads, so install it via Terraform
alongside ArgoCD rather than through ArgoCD itself.

```hcl
resource "helm_release" "karpenter" {
name = "karpenter"
namespace = "karpenter"
repository = "oci://public.ecr.aws/karpenter"
chart = "karpenter"
version = "~> 1.0"

set {
name = "settings.clusterName"
value = var.cluster_name
}
set {
name = "settings.interruptionQueue"
value = aws_sqs_queue.karpenter.name
}
set {
name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
value = module.karpenter_irsa.role_arn
}
}
```

#### NodeClass and NodePool

Manage these as Kubernetes manifests applied via Terraform (`kubectl` provider) or as
Helm values. Start with one general-purpose pool:

```yaml
# EC2NodeClass
spec:
amiSelectorTerms:
- alias: al2023@latest # Amazon Linux 2023, managed AMI updates
subnetSelectorTerms:
- tags:
kubernetes.io/role/internal-elb: "1"
securityGroupSelectorTerms:
- tags:
karpenter.sh/discovery: <cluster-name>

# NodePool
spec:
template:
spec:
requirements:
- key: karpenter.sh/capacity-type
operator: In
values: ["spot", "on-demand"] # prefer spot, fall back to on-demand
- key: kubernetes.io/arch
operator: In
values: ["amd64", "arm64"] # arm64 = Graviton, cheaper per vCPU
- key: karpenter.k8s.aws/instance-category
operator: In
values: ["c", "m", "r"] # exclude burstable (t-family) for predictability
limits:
cpu: "100"
disruption:
consolidationPolicy: WhenEmptyOrUnderutilized
consolidateAfter: 1m
```

### Acceptance criteria
- Deploy a test `Deployment` without toleration for the system taint — Karpenter provisions
a new node within ~60 seconds
- Delete the deployment — Karpenter consolidates and terminates the node
- Spot interruption simulation (using AWS FIS) drains the node cleanly

---

## Step 5 — ArgoCD Bootstrap

ArgoCD is the pivot point between Terraform-managed infrastructure and GitOps-managed
everything else. Install it via Terraform once; after that it manages itself.

### Terraform: Helm release

```hcl
resource "helm_release" "argocd" {
name = "argocd"
namespace = "argocd"
create_namespace = true
repository = "https://argoproj.github.io/argo-helm"
chart = "argo-cd"
version = "~> 7.0"

values = [file("${path.module}/argocd-values.yaml")]
}
```

Key Helm values:
- Set `server.service.type = ClusterIP` — expose via Ingress, not LoadBalancer
- Enable the ArgoCD API server metrics for Prometheus scraping
- Configure resource limits on all components
- Disable the built-in Dex for now; add SSO (GitHub OAuth via Dex) once the stack is stable
- Set `configs.cm."application.resourceTrackingMethod" = annotation` — more robust than
label-based tracking

### GitOps repo structure

Once ArgoCD is running, create the GitOps directory layout and point ArgoCD at it:

```
gitops/
bootstrap/
root-app.yaml # The one ArgoCD Application Terraform creates
platform-appset.yaml # ApplicationSet for platform components
monitoring-appset.yaml
argo-suite-appset.yaml
apps-appset.yaml
platform/
aws-load-balancer-controller/
values.yaml
external-dns/
values.yaml
cert-manager/
values.yaml
external-secrets/
values.yaml
cloudnative-pg/
values.yaml
monitoring/
kube-prometheus-stack/
values.yaml
loki/
values.yaml
tempo/
values.yaml
alloy/
values.yaml
argo-suite/
argo-workflows/
values.yaml
argo-events/
values.yaml
argo-rollouts/
values.yaml
argocd-image-updater/
values.yaml
apps/
receiver/
Chart.yaml
values.yaml
api/
Chart.yaml
values.yaml
worker/
Chart.yaml
values.yaml
charts/ # Custom Helm chart sources for your own services
receiver/
api/
worker/
```

### App-of-Apps pattern

Terraform creates one ArgoCD `Application` that points at `gitops/bootstrap/`. That app
creates ApplicationSets for each layer. ApplicationSets discover apps from the directory
structure and create `Application` resources automatically — adding a new component is
as simple as creating a new directory with a `values.yaml`.

### Acceptance criteria
- ArgoCD UI accessible (port-forward or via Ingress)
- `root-app` is healthy and green in the UI
- Changes to `gitops/` committed to `main` sync automatically within 3 minutes (default
poll interval — set webhook for instant sync once External DNS and cert-manager are up)

---

## Step 6 — Platform Components

All installed via ArgoCD ApplicationSets targeting `gitops/platform/`. Each component gets
its own IRSA role provisioned by Terraform and its ARN passed in via Helm values (or an
ExternalSecret once ESO is running).

### AWS Load Balancer Controller

Provisions ALBs from `Ingress` resources and NLBs from `Service` of type `LoadBalancer`.
Required for any externally-accessible service.

- IRSA role with the AWS-managed LBC policy (large policy, get it from the LBC docs)
- Set `clusterName` in Helm values
- Create an `IngressClass` resource named `alb` and set it as default
- Enable shield and WAF integration only if needed (adds cost)

### External DNS

Automatically creates Route53 records from `Ingress` hostnames and `Service` annotations.
Eliminates manual DNS management.

- IRSA role with Route53 `ChangeResourceRecordSets` + `ListHostedZones` + `ListResourceRecordSets`
- Set `domainFilters` to your hosted zone(s) to prevent it from touching records it shouldn't
- Set `policy: sync` (creates and deletes) rather than `upsert-only` (only creates)
- Annotate Ingress resources with `external-dns.alpha.kubernetes.io/hostname`

### cert-manager

Automatic TLS certificate issuance and renewal.

- IRSA role for DNS-01 challenge (Route53) — needed for wildcard certs and private clusters
- Create a `ClusterIssuer` for Let's Encrypt (staging first, then production)
- Alternatively: use AWS ACM certificates and the LBC's `alb.ingress.kubernetes.io/certificate-arn`
annotation — simpler but less portable
- Recommendation: cert-manager with DNS-01 — you learn more and it works without ACM

### External Secrets Operator

Syncs secrets from AWS Secrets Manager into Kubernetes `Secret` objects. Keeps plaintext
secrets out of git and out of Helm values.

- IRSA role with `secretsmanager:GetSecretValue` + `secretsmanager:DescribeSecret`
- Create a `ClusterSecretStore` backed by AWS Secrets Manager
- Usage: create an `ExternalSecret` that references a Secrets Manager path — ESO creates
and rotates the corresponding Kubernetes `Secret`
- Use for: database passwords, API keys, ArgoCD SSO client secrets, image registry credentials

### CloudNativePG

A Postgres operator that manages the full lifecycle of PostgreSQL clusters as a Kubernetes
custom resource. Significantly better than running Postgres as a plain StatefulSet.

- Install the operator chart
- No IRSA needed for the operator itself; individual `Cluster` resources can be configured
to backup to S3 (add an IRSA role for that when setting up the application)
- A `Cluster` resource defines the Postgres cluster declaratively — replicas, storage class,
backup schedule, recovery configuration
- The operator handles failover, rolling upgrades, and `pg_basebackup` — things you would
otherwise script yourself

### Acceptance criteria
- `kubectl get ingress` results in a provisioned ALB within ~90 seconds
- A test `Ingress` hostname resolves in Route53
- cert-manager issues a Let's Encrypt certificate for a test hostname
- An `ExternalSecret` syncs a test secret from Secrets Manager into a `Secret` object
- A CloudNativePG `Cluster` comes up healthy with primary + 1 replica

---

## Step 7 — Argo Suite

All four components are installed via ArgoCD from `gitops/argo-suite/`. They are
interconnected — Argo Events triggers Argo Workflows, and Argo Rollouts uses Prometheus
metrics for analysis. Install in dependency order.

### Argo Workflows

A workflow engine for running DAGs and steps as Kubernetes pods. Used for CI-style tasks,
data processing, and anything that needs orchestrated multi-step execution.

- Install with `server.authMode: server` initially (simpler); lock down with SSO later
- Configure S3 as the artifact repository (create an S3 bucket + IRSA role)
— workflow logs and output artifacts are stored here and accessible from the UI
- Set resource limits on workflow pods via `defaults` in the `ConfigMap`
- Create a `ServiceAccount` with appropriate RBAC for workflows that need to interact
with Kubernetes (e.g. triggering other workflows, updating ConfigMaps)
- Expose the UI via Ingress + cert-manager TLS

Key concepts to implement:
- `WorkflowTemplate` — reusable workflow definitions (define your build/deploy templates here)
- `CronWorkflow` — scheduled workflows (e.g. nightly data pulls)
- `ClusterWorkflowTemplate` — cluster-scoped templates shared across namespaces

### Argo Events

An event-driven automation framework. EventSources listen to external events (webhooks,
SQS, S3, Kafka, etc.) and Sensors trigger actions (submit a Workflow, call a URL, etc.).

- Install EventBus (uses NATS by default — simple, no external dependency)
- Create an `EventSource` for GitHub webhooks — listens for `push` events on your
application repos
- Create a `Sensor` that responds to the EventSource and submits an Argo Workflow
(`WorkflowTemplate` trigger)
- This gives you a self-hosted CI trigger: push to a branch → webhook → Argo Events →
Argo Workflow runs a build or test job

Additional EventSources to wire up once running:
- SNS/SQS (for AWS events)
- S3 (object created events)
- Calendar (cron-based, simpler alternative to CronWorkflow for some use cases)

### Argo Rollouts

Progressive delivery controller. Replaces the standard `Deployment` for application
workloads with a `Rollout` resource that supports canary, blue-green, and A/B strategies.

- Install the controller and the kubectl plugin (`brew install argoproj/tap/kubectl-argo-rollouts`)
- Integrates with the AWS Load Balancer Controller for traffic splitting via weighted
target groups — no service mesh required
- Integrates with Prometheus for automated analysis during rollouts

**Canary strategy (recommended starting point):**
```yaml
spec:
strategy:
canary:
steps:
- setWeight: 10 # send 10% of traffic to new version
- pause: {duration: 2m}
- analysis: # run AnalysisTemplate against Prometheus
templates:
- templateName: error-rate
- setWeight: 50
- pause: {duration: 2m}
- setWeight: 100
```

**AnalysisTemplate (error rate example):**
```yaml
spec:
metrics:
- name: error-rate
interval: 1m
successCondition: result[0] < 0.05 # fail if >5% error rate
provider:
prometheus:
address: http://prometheus:9090
query: |
rate(http_requests_total{status=~"5.."}[2m])
/
rate(http_requests_total[2m])
```

### ArgoCD Image Updater

Watches ECR for new image tags and updates the running application by either:
- Writing the new tag back to git (GitOps-correct, leaves an audit trail)
- Updating the live ArgoCD application directly (faster, no git commit)

Recommend the **git write-back** approach:
- Image Updater commits the new tag to a specific file in the GitOps repo
- ArgoCD detects the change and syncs
- Full audit trail, works with Argo Rollouts (the Rollout sees the new tag and begins
the canary process automatically)

Configuration:
- IRSA role with `ecr:DescribeImages` + `ecr:ListImages` + `ecr:BatchGetImage`
- Per-application annotation on the ArgoCD `Application`:
```yaml
argocd-image-updater.argoproj.io/image-list: api=ACCOUNT.dkr.ecr.REGION.amazonaws.com/platform-lab/api
argocd-image-updater.argoproj.io/api.update-strategy: semver
argocd-image-updater.argoproj.io/write-back-method: git
```
- Tag strategy: `semver` (tracks latest `v*.*.*`) or `latest` (tracks the `latest` tag)

### Acceptance criteria
- Submit a `Workflow` manually via the UI — it completes successfully
- Push a commit to a connected repo — Argo Events triggers a workflow automatically
- Deploy a `Rollout` and promote it through a canary manually using the kubectl plugin
- Push a new image to ECR — Image Updater detects it, commits to git, ArgoCD syncs,
Rollout begins automatically

---

## Step 8 — Observability Stack

All components installed via ArgoCD from `gitops/monitoring/`. The goal is a unified
observability platform: metrics in Prometheus, logs in Loki, traces in Tempo, all
visualised in Grafana with pre-wired datasources.

### kube-prometheus-stack

Single Helm chart that installs Prometheus, Alertmanager, Grafana, and a set of
`ServiceMonitor` / `PodMonitor` / `PrometheusRule` CRDs plus sane default dashboards
for cluster and workload metrics.

Key Helm values:
- Set `grafana.adminPassword` via ExternalSecret (not in values.yaml)
- Disable the built-in Grafana if you plan to manage it separately; but keeping it in
the stack is simpler and the default dashboards come pre-wired
- Set `prometheus.prometheusSpec.retention = 7d` for dev (keep storage small)
- Set storage class and size for Prometheus PVC (EBS via the EBS CSI driver)
- Enable `serviceMonitorSelectorNilUsesHelmValues: false` so Prometheus picks up
`ServiceMonitor` resources from all namespaces, not just the monitoring namespace

Out-of-the-box dashboards include: node exporter, kubelet, CoreDNS, kube-state-metrics,
Argo Rollouts, and more via community mixins.

### Loki

Log aggregation — pairs with Grafana for log querying alongside metrics.

- Use `SimpleScalable` mode (read + write + backend components) for dev — cheaper than
the full `Distributed` mode, more realistic than `SingleBinary`
- Use S3 as the storage backend (provision bucket + IRSA role via Terraform):
- IRSA needs: `s3:PutObject`, `s3:GetObject`, `s3:DeleteObject`, `s3:ListBucket`
- Configure a `RetentionPeriod` of 14 days for dev

Loki does not scrape logs itself — it receives them from a collector (Alloy, below).

### Grafana Alloy

The successor to Promtail and the Grafana Agent. A single binary that collects logs,
metrics, and traces and forwards them to the appropriate backends.

Deploy as a `DaemonSet` to collect from every node.

Configure Alloy to:
- Collect container logs via the Kubernetes API (structured JSON logs are automatically
parsed into Loki labels)
- Forward logs to Loki
- Scrape node-level metrics and forward to Prometheus (if not already covered by node exporter)
- Receive OTLP traces from application pods and forward to Tempo

Alloy uses a River/Alloy configuration language — expressive and composable. Start with
the standard Kubernetes log collection pipeline, then add trace forwarding.

### Tempo

Distributed tracing backend — stores and queries traces.

- Use S3 as the storage backend (separate bucket from Loki; provision via Terraform)
- IRSA needs same S3 permissions as Loki
- Enable `traces.search.enabled = true` for trace search in Grafana
- Configure the TraceQL query frontend

**Trace correlation:** Tempo integrates with Loki (link from a log line to the trace that
produced it) and with Prometheus (Exemplars — link from a metric data point to the
specific trace that caused a latency spike). These correlations are configured in
Grafana datasource settings.

### OpenTelemetry Collector

A vendor-neutral telemetry pipeline. Runs as a `Deployment` (or DaemonSet) in the cluster
and receives telemetry from application pods over OTLP (gRPC or HTTP).

- Applications send to the collector's OTLP endpoint instead of directly to backends
- The collector fans out: traces → Tempo, metrics → Prometheus remote write, logs → Loki
- This decouples applications from backend specifics — swap backends without changing
application config

For the application (Step 9), instrument with the OpenTelemetry Go SDK and point it at
the collector's in-cluster service endpoint.

### Grafana datasources and dashboards

Configure all datasources in Helm values so they are provisioned automatically — never
configure them manually in the UI (they will be lost on pod restart unless persistence
is enabled):

```yaml
grafana:
additionalDataSources:
- name: Loki
type: loki
url: http://loki-gateway.monitoring.svc.cluster.local
- name: Tempo
type: tempo
url: http://tempo-query-frontend.monitoring.svc.cluster.local:3100
jsonData:
tracesToLogsV2:
datasourceUid: loki # link traces to logs
lokiSearch:
datasourceUid: loki
```

Import community dashboards by ID in Helm values:
- `315` — Kubernetes cluster overview
- `13770` — Loki logs dashboard
- `16098` — Tempo/tracing overview
- `19105` — ArgoCD dashboard

### Acceptance criteria
- Grafana shows live cluster metrics on the default dashboards
- `kubectl logs` for any pod also appears queryable in Loki within 30 seconds
- A manual trace (via `curl` with the test app) appears in Tempo and links to its log lines
- Prometheus fires an alert to Alertmanager on a simulated condition (e.g. scale a
deployment to 0, watch the pod-not-running alert fire)

---

## Step 9 — Application

A small Go multi-service application that exercises every part of the platform. Three
services, one database, one shared purpose.

### Services

**`receiver`** — HTTP webhook endpoint
- Accepts inbound webhooks (GitHub push events, or arbitrary JSON)
- Validates HMAC signatures
- Publishes events to the Argo Events EventSource HTTP endpoint (or writes to a DB queue)
- Responds 202 Accepted immediately — no synchronous processing
- Metrics: requests/sec, validation failures, upstream publish latency
- Logs: structured JSON with `trace_id` field for correlation

**`api`** — REST API
- CRUD for stored events and workflow results
- Health endpoints: `/healthz` (liveness), `/readyz` (readiness — checks DB connection)
- Prometheus metrics via `/metrics` (use `prometheus/client_golang`)
- OTLP trace instrumentation on all HTTP handlers and DB queries
- Structured JSON logging with trace context propagation

**`worker`** — Background processor
- Triggered by Argo Workflows (Argo Events → Workflow → worker pod runs to completion)
- Pulls work items, processes them, writes results back to DB via the API
- Also runnable as a long-lived process for polling-based triggers
- Exposes Prometheus metrics even as a batch job (push to Pushgateway on completion)

### Infrastructure

**PostgreSQL** via CloudNativePG:
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
name: platform-lab-db
spec:
instances: 2
storage:
size: 5Gi
storageClass: gp3
backup:
barmanObjectStore:
destinationPath: s3://platform-lab-db-backups/
s3Credentials:
inheritFromIAMRole: true # IRSA
retentionPolicy: "7d"
```

**Kubernetes resources per service:**
- `Rollout` (not `Deployment`) — enables Argo Rollouts canary
- `Service` + `ServiceMonitor` — Prometheus scraping
- `Ingress` — ALB via LBC, DNS via External DNS, TLS via cert-manager
- `ExternalSecret` — pulls DB password from Secrets Manager
- `ServiceAccount` — with IRSA annotation if the service needs AWS access

### Helm charts

Write a Helm chart per service in `gitops/charts/`. Keep them simple:
- `deployment.yaml` → actually a `Rollout` resource
- `service.yaml`
- `ingress.yaml`
- `servicemonitor.yaml`
- `externalsecret.yaml`
- `configmap.yaml` for non-sensitive config

Use a shared `_helpers.tpl` with common label patterns. Avoid over-engineering — a
flat chart per service is easier to reason about than an umbrella chart with subcharts
at this scale.

### CI: building and pushing images

GitHub Actions workflow (`ci-images.yml`), triggers on push to `main` or version tag:

```
1. Checkout
2. Set up QEMU (for multi-arch builds)
3. Set up Docker Buildx
4. Assume ECR push role via OIDC
5. docker buildx build --platform linux/amd64,linux/arm64
6. Push to ECR with tag: git SHA + semver tag if present
```

Multi-arch builds (`amd64` + `arm64`) let Karpenter schedule pods on Graviton nodes
(cheaper per vCPU) without image compatibility issues.

### Acceptance criteria
- All three services deploy via ArgoCD and show green
- `receiver` accepts a webhook, the event appears queryable via the `api`
- A workflow triggered by Argo Events runs the `worker` against the event
- Grafana shows per-service metrics, logs, and traces all linked together
- Pushing a new image triggers the full loop: ECR → Image Updater → git commit →
ArgoCD sync → Argo Rollouts canary → automatic promotion

---

## Step 10 — Close the Delivery Loop

Wire Image Updater, Rollouts, and observability together into a complete progressive
delivery pipeline. This is where all the individual pieces compose into something
end-to-end.

### Full pipeline

```
Developer pushes code
│
▼
GitHub Actions builds image, pushes to ECR with semver tag (e.g. v1.2.3)
│
▼
ArgoCD Image Updater detects new tag in ECR
│
▼
Image Updater commits updated image tag to gitops/apps/api/values.yaml
│
▼
ArgoCD detects git change, syncs the Application
│
▼
Argo Rollouts begins canary: 10% traffic to new version
│
▼
AnalysisRun queries Prometheus: error rate, latency p99
┌────┴────┐
success failure
│ │
▼ ▼
promote abort + roll back automatically
(100%) (old version stays live)
```

### AnalysisTemplate refinements

Once you have real traffic and real metrics, tune the analysis:

```yaml
spec:
metrics:
- name: error-rate
interval: 1m
failureLimit: 1
successCondition: result[0] < 0.01 # <1% errors
provider:
prometheus:
query: |
sum(rate(http_requests_total{app="api",status=~"5.."}[2m]))
/
sum(rate(http_requests_total{app="api"}[2m]))

- name: latency-p99
interval: 1m
successCondition: result[0] < 0.5 # p99 < 500ms
provider:
prometheus:
query: |
histogram_quantile(0.99,
rate(http_request_duration_seconds_bucket{app="api"}[2m])
)
```

### Notifications

ArgoCD has a built-in notifications engine. Configure it to post to a Slack channel
(or GitHub PR comment) on:
- Rollout started
- Rollout promoted
- Rollout aborted (most important — you want to know immediately)
- Sync failed

### Chaos / validation

Once the loop is stable, try breaking it intentionally:

- Deploy a version with an intentional bug (e.g. return 500 on 20% of requests)
- Watch the AnalysisRun fail and the rollout abort automatically
- Verify the old version is still live and healthy throughout

This validates that the safety net actually works, which is the whole point of
progressive delivery.

### Final acceptance criteria
- A code change to the application goes from `git push` to a promoted canary with
zero manual intervention
- A bad deploy aborts and rolls back without any downtime to end users
- The full rollout is visible in Grafana: traffic shift, error rate, latency, all
correlated with the deployment event
- All components are defined in git — the cluster can be rebuilt from scratch by
running `terragrunt apply` and waiting for ArgoCD to sync