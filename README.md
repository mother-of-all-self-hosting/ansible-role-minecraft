<!--
SPDX-FileCopyrightText: 2023, 2026 Slavi Pantaleev
SPDX-FileCopyrightText: 2025 XHawk87
SPDX-FileCopyrightText: 2025, 2026 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Minecraft Server Ansible role

This is an [Ansible](https://www.ansible.com/) role which installs [Minecraft Server (Java Edition)](https://docker-minecraft-server.readthedocs.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

This role *implicitly* depends on:

- [`com.devture.ansible.role.playbook_help`](https://github.com/devture/com.devture.ansible.role.playbook_help)
- [`com.devture.ansible.role.systemd_docker_base`](https://github.com/devture/com.devture.ansible.role.systemd_docker_base)

Check [defaults/main.yml](defaults/main.yml) for the full list of supported options.

💡 For an Ansible playbook which integrates this role and makes it easier to use, see the [Mother-of-All-Self-Hosting Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

>[!NOTE]
> By running the role you implicitly agree to the [Mojang EULA for Minecraft](https://www.minecraft.net/en-us/eula). The role sets `EULA=TRUE` for the container by default (see `minecraft_environment_variables_eula`); the server refuses to start without it.

## Which Minecraft version you get

`minecraft_docker_version` pins the [itzg/minecraft-server](https://docker-minecraft-server.readthedocs.io/) image, which is a launcher — it is **not** the Minecraft version. The Minecraft version comes from the image's `VERSION` environment variable, which defaults to `LATEST`. Two consequences are worth knowing about before you run a server anybody cares about:

- **The world is upgraded forward-only.** With `VERSION=LATEST`, a restart that happens to land after a new Minecraft release starts that release against your existing world. Minecraft rewrites the world's region files into the newer format on load, and an older server will then refuse to open them. This role takes no backup of `minecraft_data_path` for you. Pin `VERSION` to a concrete Minecraft release if you would rather choose when that happens:

  ```yaml
  minecraft_environment_variables_additional_variables: |
    VERSION=1.21.4
  ```

- **Leave the image tag unflavoured unless you also pin `VERSION`.** The `-javaNN` (and `-alpine`, `-graalvm`, …) flavours of the image pin a specific JRE, and a Minecraft release built for a newer JRE will not start on them — it dies with `UnsupportedClassVersionError`, and because the systemd unit uses `Restart=always` the unit keeps reporting `active` while the container crash-loops. The unflavoured tag tracks the JRE upstream currently builds against, which is what `VERSION=LATEST` needs.

## Development

### pre-commit

You can optionally install a Git pre-commit hook (via [mise](https://mise.jdx.dev/) + [prek](https://prek.j178.dev/)) that runs formatting and linting checks before each commit. See [`.pre-commit-config.yaml`](./.pre-commit-config.yaml) for which hooks are to be executed.

To install the hook, run the [`just`](https://github.com/casey/just) command below:

```sh
just prek-install-git-pre-commit-hook
```

### Molecule

This role supports [Molecule](https://docs.ansible.com/projects/molecule/), an Ansible testing framework designed for developing and testing Ansible collections, playbooks, and roles.

Refer to [this page](./molecule/README.md) for details about how to utilize it.
