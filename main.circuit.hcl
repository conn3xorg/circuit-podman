locals {
  units_dir = "/etc/containers/systemd"
  env_dir   = "/etc/containers/env"

  # Each container's Quadlet file. Quadlet reads systemd's quoting, so values
  # that may hold spaces are written as quoted strings.
  units = {
    for name, c in var.containers : name => join("\n", concat(
      [
        "# Managed by Conn3x.",
        "[Unit]",
        "Description=${name} container",
        "Wants=network-online.target",
        "After=network-online.target",
        "",
        "[Container]",
        "Image=${c.image}",
        "ContainerName=${name}",
        "EnvironmentFile=${local.env_dir}/${name}.env",
      ],
      [for p in c.ports : "PublishPort=${p}"],
      [for v in c.volumes : "Volume=${v}"],
      [for k, v in c.environment : "Environment=${jsonencode("${k}=${v}")}"],
      c.auto_update ? ["AutoUpdate=registry"] : [],
      c.extra,
      [
        "",
        "[Service]",
        "Restart=always",
        # The first start pulls the image, which can take longer than
        # systemd's default 90 seconds.
        "TimeoutStartSec=900",
        "",
        "[Install]",
        "WantedBy=default.target",
        "",
      ],
    ))
  }
}

circuit "podman" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    package {
      name = "podman"
    }
  }

  step "registries" {
    for_each = toset(length(var.registries) > 0 ? ["search"] : [])
    file {
      path      = "/etc/containers/registries.conf.d/50-conn3x.conf"
      content   = "# Managed by Conn3x.\nunqualified-search-registries = ${jsonencode(var.registries)}\n"
      on_remove = "delete"
    }
  }

  # Every container gets an env file, empty when it has no secrets, so the
  # unit can always name it.
  step "env" {
    for_each = var.containers
    file {
      path       = "${local.env_dir}/${item.key}.env"
      content_wo = join("", [for k, v in try(var.secrets[item.key], {}) : "${k}=${v}\n"])
    }
  }

  step "unit" {
    for_each = var.containers
    file {
      path    = "${local.units_dir}/${item.key}.container"
      content = local.units[item.key]
    }
  }

  # Quadlet generates NAME.service on daemon-reload. A changed unit or env
  # file restarts only that container; the first apply starts it.
  step "restart" {
    for_each = var.containers
    command {
      command = "systemctl daemon-reload && systemctl restart '${item.key}.service'"
      triggers = {
        unit = conn3x_file.podman__unit["${each.key}/${item.key}"].revision
        env  = conn3x_file.podman__env["${each.key}/${item.key}"].revision
      }
    }
  }

  # Starts a container that stopped. Generated units can't be enabled; the
  # [Install] section starts them at boot.
  step "running" {
    for_each = var.containers
    service {
      name  = "${item.key}.service"
      state = "started"
    }
  }

  step "auto_update" {
    for_each = toset(var.auto_update_timer ? ["timer"] : [])
    service {
      name    = "podman-auto-update.timer"
      state   = "started"
      enabled = true
    }
  }
}
