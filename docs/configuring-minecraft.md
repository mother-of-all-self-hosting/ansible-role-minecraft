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

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Minecraft Server on Docker (Java Edition)

This is an [Ansible](https://www.ansible.com/) role which installs [Minecraft Server (Java Edition)](https://docker-minecraft-server.readthedocs.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Minecraft is a first-person open-world procedurally-generated voxel-based sandbox game with RPG elements. The Docker image which this role installs provides a Minecraft Server which will automatically download the latest stable version at startup. You can also run/upgrade to any specific version or the latest snapshot.

See the project's [documentation](https://docker-minecraft-server.readthedocs.io/en/latest/) to learn what the server does and why it might be useful to you.

>[!WARNING]
> Minecraft Server on Docker (Java Edition) is published under the Apache-2.0 license, but Minecraft itself is proprietary software, and by using this role you are agreeing to the [EULA](https://www.minecraft.net/en-us/eula).

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

### Extending the configuration

There are some additional things you may wish to configure about the service.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `minecraft_environment_variables_additional_variables` variable

Refer to [the official documentation](https://docker-minecraft-server.readthedocs.io/en/latest/variables/) for a complete list of Minecraft Server's config options that you can put in `minecraft_environment_variables_additional_variables`.

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

minecraft_environment_variables_additional_variables: |
  MOTD=[Your Server Name Here]
  TYPE=PAPER
  VERSION=latest
  INIT_MEMORY=500M
  MAX_MEMORY=2G
  USE_AIKAR_FLAGS=true
  STOP_SERVER_ANNOUNCE_DELAY=10
  TZ=Europe/London
  LOG_TIMESTAMP=true
  DIFFICULTY=hard
  ENABLE_WHITELIST=true
  ENFORCE_WHITELIST=true
  WHITELIST=[Your Minecraft IGN Here]
  ENABLE_QUERY=false
  MAX_PLAYERS=20
  ENABLE_COMMAND_BLOCK=true
  SNOOPER_ENABLED=false
  SPAWN_PROTECTION=0
  VIEW_DISTANCE=16
  PVP=true
  ALLOW_FLIGHT=TRUE
  SIMULATION_DISTANCE=16
  PLAYER_IDLE_TIMEOUT=0
  INITIAL_ENABLED_PACKS=vanilla,bundle
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
