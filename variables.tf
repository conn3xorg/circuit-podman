variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "containers" {
  type = map(object({
    image       = string
    ports       = optional(list(string), [])
    volumes     = optional(list(string), [])
    environment = optional(map(string), {})
    extra       = optional(list(string), [])
    auto_update = optional(bool, false)
  }))
  default     = {}
  description = "Containers to run as systemd services through Quadlet, by name. Each becomes /etc/containers/systemd/NAME.container and the service NAME.service."

  validation {
    condition     = alltrue([for name in keys(var.containers) : can(regex("^[a-z0-9][a-z0-9_.-]*$", name))])
    error_message = "Container names may use lowercase letters, digits, ., - and _, since each one is also a systemd unit name."
  }

  validation {
    # The last path segment must carry a tag or a digest, so the image can't
    # move under you as :latest.
    condition     = alltrue([for c in values(var.containers) : can(regex("^[^\\s]+$", c.image)) && can(regex("[:@]", reverse(split("/", c.image))[0]))])
    error_message = "Each image needs a tag or a digest, such as \"docker.io/library/nginx:1.29-alpine\" or \"quay.io/app/api@sha256:...\"."
  }

  validation {
    # podman auto-update refuses short names, so catch them here.
    condition     = alltrue([for c in values(var.containers) : !c.auto_update || (length(split("/", c.image)) > 1 && can(regex("[.:]|^localhost$", split("/", c.image)[0])))])
    error_message = "A container with auto_update needs a fully qualified image that starts with its registry, such as \"docker.io/traefik/whoami:v1.11\"."
  }

  validation {
    condition     = alltrue(flatten([for c in values(var.containers) : [for k in keys(c.environment) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))]]))
    error_message = "Environment variable names may use letters, digits and _, and can't start with a digit."
  }
}

variable "secrets" {
  type        = map(map(string))
  default     = {}
  ephemeral   = true
  sensitive   = true
  description = "Secret environment variables by container name, such as { app = { DB_PASSWORD = \"...\" } }. They go to /etc/containers/env/NAME.env with mode 0600 and never reach state or the plan."

  validation {
    condition     = alltrue([for name in keys(var.secrets) : contains(keys(var.containers), name)])
    error_message = "Each key of secrets must be the name of a container in containers."
  }

  validation {
    condition     = alltrue(flatten([for env in values(var.secrets) : [for k in keys(env) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))]]))
    error_message = "Secret variable names may use letters, digits and _, and can't start with a digit."
  }
}

variable "registries" {
  type        = list(string)
  default     = []
  description = "Registries to search for short image names, such as [\"docker.io\"]. Give one: with two or more, Podman refuses short names when it has no terminal to ask on, as under systemd. When empty, the distribution's own setting stays."

  validation {
    condition     = alltrue([for r in var.registries : can(regex("^[a-z0-9.-]+(:[0-9]+)?$", r))])
    error_message = "Each of registries must be a host name, optionally with a port, such as \"docker.io\" or \"registry.lan:5000\"."
  }
}

variable "auto_update_timer" {
  type        = bool
  default     = false
  description = "Start podman-auto-update.timer, which pulls new images for containers with auto_update once a day and restarts them."
}
