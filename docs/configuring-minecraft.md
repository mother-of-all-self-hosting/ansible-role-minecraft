<!--
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2020-2024 MDAD project contributors
SPDX-FileCopyrightText: 2020-2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2025 XHawk87

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Minecraft Server on Docker (Java Edition)

This is an [Ansible](https://www.ansible.com/) role which installs [Minecraft Server (Java Edition)](https://docker-minecraft-server.readthedocs.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Minecraft is a first-person open-world procedurally-generated voxel-based sandbox game with RPG elements. The Docker image which this role installs provides a Minecraft Server which will automatically download the latest stable version at startup. You can also run/upgrade to any specific version or the latest snapshot.

See the project's [documentation](https://docker-minecraft-server.readthedocs.io/en/latest/) to learn what the server does and why it might be useful to you.

>[!WARNING]
> Minecraft Server on Docker (Java Edition) is published under the Apache-2.0 license, but Minecraft itself is proprietary software. By using this role you are agreeing to the [EULA](https://www.minecraft.net/en-us/eula). The role sets `EULA=TRUE` for the container by default (see `minecraft_environment_variables_eula`); the server refuses to start without it.

## Adjusting the playbook configuration

To enable Minecraft Server with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# minecraft                                                            #
#                                                                      #
########################################################################

minecraft_enabled: true

########################################################################
#                                                                      #
# /minecraft                                                           #
#                                                                      #
########################################################################
```

### Selecting Minecraft version you get (optional)

`minecraft_docker_version` pins the Minecraft Server image. It is **not** the Minecraft version. The Minecraft version comes from the `minecraft_environment_variables_version` variable, which defaults to `LATEST`.

Two consequences are worth knowing about before you run a server anybody cares about:

- **The world is upgraded forward-only.** With `minecraft_environment_variables_version: LATEST`, a restart that happens to land after a new Minecraft release starts that release against your existing world. Minecraft then rewrites the world's region files into the newer format on load, and an older server will then refuse to open them. If you want to choose when that happens, pin `minecraft_environment_variables_version` to a concrete Minecraft release by adding the following configuration to your `vars.yml` file.

  ```yaml
  minecraft_environment_variables_version: 1.23.4
  ```

- **Leave the image tag unflavoured unless you also pin `VERSION`.** The `-javaNN` (and `-alpine`, `-graalvm`, …) flavours of the image pin a specific JRE, and a Minecraft release built for a newer JRE will not start on them. The unflavoured tag tracks the JRE upstream currently builds against, which is what `VERSION=LATEST` needs.

Refer to [this page](https://docker-minecraft-server.readthedocs.io/en/latest/versions/minecraft/) on the documentation for details about versions.

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `minecraft_environment_variables_additional_variables` variable

Refer to [the official documentation](https://docker-minecraft-server.readthedocs.io/en/latest/variables/) for a complete list of Minecraft Server's config options that you can put in `minecraft_environment_variables_additional_variables`.

### Exposing plugin web interfaces through Traefik (optional)

Some plugins run a web server inside the Minecraft container. Examples are [BlueMap](https://bluemap.bluecolored.de/) and [Dynmap](https://github.com/webbukkit/dynmap), which serve an interactive map of the world.

To expose such an interface through [Traefik](https://doc.traefik.io/traefik/), add it to `minecraft_web_interfaces` and enable the role's Traefik labels:

```yaml
minecraft_container_labels_traefik_enabled: true
minecraft_container_labels_traefik_docker_network: traefik

# The role does not create this network. It needs to be the network your Traefik
# instance uses, and it needs to exist already.
minecraft_container_additional_networks_custom:
  - traefik

minecraft_web_interfaces:
  - name: bluemap
    hostname: bluemap.example.com
    port: 8100
  - name: dynmap
    hostname: dynmap.example.com
    port: 8123
```

Each entry needs:

- `name`: a unique name, used to build the Traefik router and service names. Use only characters which are valid in Traefik router names (e.g. lowercase letters, digits and dashes).
- `hostname`: the hostname at which the interface is served.
- `port`: the port the plugin's web server listens on inside the container.

The role attaches one router and one service per entry to the container, and points the service at `port`. The interface is only reachable over the container network, so no host port is published for it.

The following variables control the Traefik labels:

- `minecraft_container_labels_traefik_enabled` — whether to attach the labels at all. Defaults to `false`.
- `minecraft_container_labels_traefik_docker_network` — the network to put in the `traefik.docker.network` label. Defaults to `minecraft_container_network`.
- `minecraft_container_labels_traefik_entrypoints` — the Traefik entrypoint(s) to attach the routers to. Defaults to `web-secure`.
- `minecraft_container_labels_traefik_tls` — whether the routers use TLS. Defaults to `true`.
- `minecraft_container_labels_traefik_tls_certResolver` — the certificate resolver for the routers. Defaults to `default`.

When using the [MASH playbook](https://github.com/mother-of-all-self-hosting/mash-playbook), the container is attached to the Traefik network automatically when `minecraft_web_interfaces` is not empty, and the entrypoint and certificate resolver are already set. You only need to set `minecraft_web_interfaces` and configure the plugins.

Make sure the plugin's web server listens on all interfaces inside the container (`0.0.0.0`), rather than only on `127.0.0.1`, otherwise Traefik cannot reach it. Check the plugin's own configuration for its bind address; both BlueMap and Dynmap listen on all interfaces by default.

> [!NOTE]
> These labels are only for the web interfaces listed in `minecraft_web_interfaces`. Use `minecraft_container_labels_additional_labels` for any labels of your own; they are appended to the generated ones.

### Example configurations

Here is an example set of configurations for running a Minecraft Server instance with:

- hosted on port `25565` on all network interfaces — port forwarding will be required to access it
- [Paper minecraft server](https://papermc.io/)
- latest Minecraft release
- limited to 2GB of RAM
- hard difficulty
- only you on the whitelist
- generous render distance (16)
- PvP enabld
- with bundles

```yaml
minecraft_container_tcp_host_bind_port: 25565

minecraft_environment_variables_type: paper
minecraft_environment_variables_version: LATEST
minecraft_environment_variables_max_memory: 2G
minecraft_environment_variables_difficulty: hard
minecraft_environment_variables_view_distance: 16
minecraft_environment_variables_pvp: true
minecraft_environment_variables_initial_enabled_packs: vanilla,bundle
minecraft_environment_variables_additional_variables: |
  MOTD=[Your Server Name Here]
  INIT_MEMORY=500M
  USE_AIKAR_FLAGS=true
  STOP_SERVER_ANNOUNCE_DELAY=10
  LOG_TIMESTAMP=true
  ENABLE_WHITELIST=true
  ENFORCE_WHITELIST=true
  WHITELIST=[Your Minecraft IGN Here]
  ENABLE_QUERY=false
  MAX_PLAYERS=20
  ENABLE_COMMAND_BLOCK=true
  SNOOPER_ENABLED=false
  SPAWN_PROTECTION=0
  ALLOW_FLIGHT=TRUE
  SIMULATION_DISTANCE=16
  PLAYER_IDLE_TIMEOUT=0
```

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Minecraft Server becomes available. You can use your Minecraft client to log into the game.

If you need to access the server console, you can do so via RCON:

```bash
ssh -t [Your MC server hostname] \
    sudo docker exec -it mash-minecraft \
        rcon-cli
```

You can then give yourself Operator status, or perform any other MC commands you wish.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu minecraft` (or how you/your playbook named the service, e.g. `mash-minecraft`).
