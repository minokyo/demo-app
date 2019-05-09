/*
 * Copyright 2017 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}

variable "network_name" {
  default = "rga-demo-app"
}

variable "project" {
  default = ""
}

provider "google" {
  project     = "${var.project}"
  region      = "${var.region}"
  version     = "1.19.0"
}

resource "google_compute_network" "default" {
  name                    = "${var.network_name}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "default" {
  name                     = "${var.network_name}"
  ip_cidr_range            = "10.125.0.0/20"
  network                  = "${google_compute_network.default.self_link}"
  region                   = "${var.region}"
  private_ip_google_access = true
}

resource "google_compute_backend_bucket" "demo_backend" {
  name        = "demo-backend-bucket"
  description = "Contains static resources for demo app"
  bucket_name = "${google_storage_bucket.demo_bucket.name}"
  enable_cdn  = false
}

resource "google_storage_bucket" "demo_bucket" {
  name          = "rga-demo-storage-bucket"
  storage_class = "REGIONAL"
  location      = "${var.region}"

  // delete bucket and contents on destroy.
  force_destroy = true
}

data "template_file" "motd" {
  template = "${file("${format("%s/motd.html.tpl", path.module)}")}"
}

// The image object in Cloud Storage.
// Note that the path in the bucket matches the paths in the url map path rule.
resource "google_storage_bucket_object" "html" {
  name         = "static/motd.html"
  content       = "${data.template_file.motd.rendered}"
  content_type = "text/html; charset=utf-8"
  bucket       = "${google_storage_bucket.demo_bucket.name}"
  cache_control = "private"
}

resource "google_storage_bucket_object" "image" {
  name         = "static/meme.jpg"
  source       = "meme.jpg"
  content_type = "image/jpeg"
  bucket       = "${google_storage_bucket.demo_bucket.name}"
  cache_control = "private"
}

// Make object public readable.
resource "google_storage_object_acl" "html_acl" {
  bucket = "${google_storage_bucket.demo_bucket.name}"
  object = "${google_storage_bucket_object.html.name}"
  role_entity = ["READER:allUsers"]
}

resource "google_storage_object_acl" "image_acl" {
  bucket = "${google_storage_bucket.demo_bucket.name}"
  object = "${google_storage_bucket_object.image.name}"
  role_entity = ["READER:allUsers"]
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "1.0.10"
  name              = "${var.network_name}"
  target_tags       = ["${module.mig1.target_tags}"]
  firewall_networks = ["${google_compute_network.default.name}"]
  url_map           = "${google_compute_url_map.https-content.self_link}"
  create_url_map    = false
  ssl               = true
  private_key       = "${tls_private_key.example.private_key_pem}"
  certificate       = "${tls_self_signed_cert.example.cert_pem}"
  backends = {
    "0" = [
      { group = "${module.mig1.instance_group}" }
    ]
  }
  backend_params = [
    // health check path, port name, port number, timeout seconds.
    "/,${module.mig1.service_port_name},${module.mig1.service_port},10"
  ]
}

resource "google_compute_url_map" "https-content" {
  // note that this is the name of the load balancer
  name            = "${var.network_name}"
  default_service = "${module.lb-http.backend_services[0]}"

  host_rule = {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher = {
    name            = "allpaths"
    default_service = "${module.lb-http.backend_services[0]}"

    path_rule {
      paths   = ["/static", "/static/*"]
      service = "${google_compute_backend_bucket.demo_backend.self_link}"
    }
  }
}

output "group_region" {
  value = "${var.region}"
}

output "load-balancer-ip" {
  value = "${module.lb-http.external_ip}"
}

output "static-obj-url" {
  value = "https://${module.lb-http.external_ip}/static/meme.jpg"
}
