# Kargo Quickstart Template

These are the supporting files for [the Kargo Quickstart tutorial](https://docs.akuity.io/tutorials/kargo-quickstart/) in the Akuity docs.

This tutorial will walk you through a working example using Kargo with the Akuity Platform, to manage the promotion of images across multiple stages in a declarative way. This implementation extends the base quickstart using a **Grouped Services** architecture to promote multiple microservices together as a unit.

## Setup & Overall Design

This project deploys three microservices — `guestbook`, `backend`, and `queue` — through a three-stage pipeline (`dev` → `staging` → `prod`) using Kargo for promotion orchestration and Argo CD (via the Akuity Platform) for deployment.

A single Kargo `Warehouse` subscribes to all three image repositories. Each time a new image revision is discovered, the `Warehouse` produces a `Freight` resource referencing one revision of each image. This means all three services are promoted from stage to stage together as a unit.

Each stage's promotion process:
1. Clones the GitOps repo and checks out the environment branch (`env/dev`, `env/staging`, `env/prod`)
2. Updates the image tags for all three services using `kustomize-set-image`
3. Renders each service's manifests via `kustomize-build` into flat YAML files (`guestbook-manifests.yaml`, `backend-manifests.yaml`, `queue-manifests.yaml`)
4. Commits and pushes the rendered manifests to the environment branch
5. Triggers three Argo CD `Application` resources to sync to the new commit

All three services in each environment are deployed into a single shared namespace (`guestbook-simple-<env>`).

## Key Design Decisions & Tradeoffs

**Grouped Services over independent pipelines**
Rather than giving each microservice its own `Warehouse` and pipeline, a single `Warehouse` tracks all three image repos. This couples their promotion lifecycle intentionally — a change to any one service produces new `Freight` that carries all three images forward together. The tradeoff is reduced deployment flexibility; you cannot promote `backend` independently of `guestbook`. This was an acceptable tradeoff given the tight coupling between the services.

**Rendered manifests on environment branches**
Kargo builds and pushes rendered YAML to `env/<stage>` branches rather than having Argo CD run Kustomize itself. This makes the deployed state explicit and auditable in Git, at the cost of more complex promotion steps and environment branches that contain generated rather than human-authored content.

**Separate Argo CD Applications per service**
Each service (`guestbook`, `backend`, `queue`) has its own `ApplicationSet` generating one `Application` per environment. This gives visibility into the health of each service independently in Argo CD, while still being promoted together via Kargo.

**Shared destination namespace**
All three services deploy into `guestbook-simple-<env>` rather than separate namespaces per service. This simplifies RBAC and networking between tightly coupled services.

**Akuity Platform for Argo CD**
Argo CD runs on the Akuity Platform rather than in-cluster. ApplicationSets are declared in `akuity/` and applied via `akuity argocd apply`, rather than being managed by Argo CD itself.

## Assumptions

- All three microservices (`guestbook`, `backend`, `queue`) are always promoted together — independent promotion of a single service is not a requirement.
- The Akuity agent has sufficient cluster permissions to create and manage resources across namespaces.
- Environment branches (`env/dev`, `env/staging`, `env/prod`) contain only Kargo-generated rendered manifests and are not edited manually.
- Staging and prod manifests are only populated after a successful Kargo promotion from the previous stage — they will show as `OutOfSync` in Argo CD until that promotion occurs.

## Repository Structure

```
├── akuity/          # Akuity Platform declarative config (Argo CD instance, ApplicationSets)
├── app/             # Kustomize source manifests for each service
│   ├── guestbook/
│   ├── backend/
│   └── queue/
├── kargo/           # Kargo resources (Project, Warehouse, Stages)
└── scripts/         # Setup scripts for Argo CD instance and Kargo
```

## Getting Started

See the [Akuity Kargo Quickstart tutorial](https://docs.akuity.io/tutorials/kargo-quickstart/) for full setup instructions.

To apply the Argo CD instance configuration:

```bash
akuity argocd apply -f akuity/
```

To apply Kargo resources:

```bash
kubectl apply -f kargo/
```

## Additional Considerations

**What would a monorepo or portfolio deployment look like?** With monorepo deployments, they could look two different ways based on the same file structure. Within the apps folder, each subdirectory would be its own application which would contain all the relative argo files. For Kargo, there are two different patterns for monorepos, the choice of which depends on the style of continuous delivery. There could be grouped services with multiple warehouses or a single warehouse with single or multiple pipeline architectures. The deployment could happen on a PR to the main branch using PR promotions. https://docs.akuity.io/tutorials/kargo-quickstart/#333-pull-request-promotions

**How would your Kargo/Argo definitions differ for common addons like ingress, monitoring, etc?**
In Kargo, 3rd-party applications like traffic controllers or security meshes would exist with their own warehouses and pipelines with stages leveraging kustomize with helm configurations, allowing argocd to manage the helm deployments. This is because 3rd party application changes will most likely not be coupled with our applications at all so it’s best to manage them separately from our application configurations.

**Future changes:** In the future I would look to modify this a bit more to setup a blue / green deployment structure. This would reflect a real world scenario of what a lot of businesses are doing today.  
