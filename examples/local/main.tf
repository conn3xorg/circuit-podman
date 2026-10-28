variable "port" {
  type    = number
  default = 2222
}

variable "whoami_name" {
  type      = string
  default   = "from-the-env-file"
  ephemeral = true
}

module "podman" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  registries        = ["docker.io"]
  auto_update_timer = true
  containers = {
    whoami = {
      image       = "docker.io/traefik/whoami:v1.11"
      ports       = ["8080:80"]
      environment = { WHOAMI_PORT_NUMBER = "80" }
      auto_update = true
    }
  }
  secrets = {
    whoami = { WHOAMI_NAME = var.whoami_name }
  }
}
