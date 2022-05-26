locals {
    project_name  = "hero-app-351218"
    region  = "europe-west1"
    cluster_zone  = "europe-west1-d"
    cluster_name  = "hero-app-europe-west1-v1"
    k8s_namespace = "hero-namespace"
}

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.22.0"
    }
  }

  backend "gcs" {
    bucket      = "hero-app-artifacts"
    prefix      = "terraform/state"
  }

}

provider "google" {
  project = local.project_name
  region  = local.region
  zone    = local.cluster_zone
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "gke_hero-app-351218_europe-west1_hero-app-europe-west1-v1"
}

resource "google_service_account" "default" {
  account_id   = "hero-service-account"
  display_name = "Hero Service Account"
}

resource "google_project_iam_member" "hero_app_iam" {
  for_each = toset([
    "roles/iam.workloadIdentityUser", // Kubernetes identity
    "roles/storage.objectViewer"
  ])
  role = each.key
  member = "serviceAccount:${google_service_account.default.email}"
  project = local.project_name
}

resource "google_compute_network" "hero_vpc" {
  name                    = "hero-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "hero_subnet" {
  name                     = "${google_compute_network.hero_vpc.name}-subnet"
  ip_cidr_range            = "10.10.0.0/20"
  network                  = google_compute_network.hero_vpc.self_link
  region                   = local.region
  private_ip_google_access = true
}

# This will created the Kubernetes cluster and nodes in GCP
resource "google_container_cluster" "primary" {
  name               = local.cluster_name
  location          = local.region

  network            = google_compute_network.hero_vpc.name
  subnetwork         = google_compute_subnetwork.hero_subnet.name

  remove_default_node_pool = true
  initial_node_count = 1

  # configure your local kubectl to talk to the newly created cluster
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${local.cluster_name} --region ${local.region} --project ${local.project_name}"
  }
  
  timeouts {
    create = "45m" 
    update = "60m"
  }
}

resource "kubernetes_namespace" "namespace" {
  depends_on = [
    google_container_cluster.primary
  ]
  metadata {
    name = local.k8s_namespace
  }
}


resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "hero-node-pool"
  location   = local.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

 node_config {
    preemptible  = true
    machine_type = "e2-micro"

    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}