<!--
SPDX-FileCopyrightText: 2018-2025 Slavi Pantaleev
SPDX-FileCopyrightText: 2019-2022 Aaron Raimist
SPDX-FileCopyrightText: 2019-2023 MDAD project contributors
SPDX-FileCopyrightText: 2023 QEDeD
SPDX-FileCopyrightText: 2024 Fabio Bonelli
SPDX-FileCopyrightText: 2024 Nikita Chernyi
SPDX-FileCopyrightText: 2024-2026 Suguru Hirahara
SPDX-FileCopyrightText: 2026 spatterlight

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Molecule Testing

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

## Prerequisites

To utilize Molecule you need to prepare several requirements:

- **x86** computer running one of these operating systems that make use of [systemd](https://systemd.io/):
  - **Archlinux**
  - **CentOS**, **Rocky Linux**, **AlmaLinux**, or possibly other RHEL alternatives (although your mileage may vary)
  - **Debian** (10/Buster or newer)
  - **Ubuntu** (18.04 or newer, although [20.04 may be problematic](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/ansible.md#supported-ansible-versions) if you run the Ansible playbook on it)
- `root` access on the computer which Molecule runs against
- [Ansible](http://ansible.com/) program
- [Python](https://www.python.org/)
  - Most distributions install Python by default, but some don't (e.g. Ubuntu 18.04) and require manual installation (something like `apt-get install python3`)
- [Docker](https://www.docker.com)
  - Access to Docker UNIX socket (`/var/run/docker.sock`) is required by default

## Installation

To set up the environment for using Molecule, run the command below on the terminal:

```bash
python3 -m venv ./molecule/venv
source ./molecule/venv/bin/activate
pip3 install -r ./molecule/requirements.txt
```

## Scenarios

Currently there is one testing scenario available.

### `default`

Installs the role, starts the systemd service and then verifies the Minecraft server over the Minecraft protocol itself.

The verification performs a [Server List Ping](https://minecraft.wiki/w/Java_Edition_protocol/Server_List_Ping) — the handshake and status request a Minecraft client makes to render a server in its server list — using [`files/server-list-ping.py`](default/files/server-list-ping.py), which needs nothing beyond the Python standard library. It serves as both the readiness gate and the probe, because the systemd unit runs with `Restart=always`: a crash-looping container keeps the unit `active`, so `systemctl is-active` proves nothing on its own.

From the reply and the service journal, the scenario asserts that:

- the server reports the MOTD and the player slot count that the role's `env` template configured (an unconfigured server reports `A Minecraft Server` and 20 slots);
- the container announced the image version that `minecraft_docker_version` pins in `defaults/main.yml` — the literal Renovate edits — so a version bump is exercised at the bumped version;
- the server bound the port set through `minecraft_container_tcp_port`, rather than merely having that port published towards it;
- `NRestarts` on the systemd unit is zero, so the server has never been resurrected by the `Restart=` policy;
- a world was written, and the server comes back up over that existing world after a `systemctl restart`.

The scenario leaves the image's `VERSION` at its default of `LATEST`, so it downloads and runs whatever Minecraft release is current. That is deliberate: it is what a default installation of this role does, and it is what catches the image's pinned JRE falling behind what current Minecraft needs.

## Running

By default it is configured to run the scenarios on Ubuntu 26.04.

```bash
molecule test --scenario-name default
```

You can utilize other distributions by setting one to the `MOLECULE_DISTRO` environment variable:

```bash
# Ubuntu 24.04
MOLECULE_DISTRO=ubuntu2404 molecule test --scenario-name default

# Debian 13
MOLECULE_DISTRO=debian13 molecule test --scenario-name default

# Debian 12
MOLECULE_DISTRO=debian12 molecule test --scenario-name default
```
