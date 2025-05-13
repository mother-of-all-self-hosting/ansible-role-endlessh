<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Endlessh

This is an [Ansible](https://www.ansible.com/) role which installs [Endlessh-go](https://github.com/shizunge/endlessh-go), a Golang implementation of [Endlessh](https://nullprogram.com/blog/2019/03/22), to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Endlessh is an SSH tarpit, one of the methods to guard an SSH server from attackers. The program opens a socket and pretends to be an SSH server, but it just ties up SSH clients with false promises indefinitely until the client eventually gives up. It not only blocks blute force attacks to the server but also aims to waste attacker's time and resources.

See the project's [documentation](https://github.com/shizunge/endlessh-go/blob/main/README.md) to learn what Endlessh-go does and why it might be useful to you.

## Prerequisites

This role is configured to set up the Endlessh-go instance to listen to the port 22, the standard SSH port, therefore you need to move the port for the real SSH server to another port, so that an Endlessh-go instance can listen to the port 22 and trap attackers' clients into it.

## Adjusting the playbook configuration

To enable Endlessh-go with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# endlessh                                                             #
#                                                                      #
########################################################################

endlessh_enabled: true

########################################################################
#                                                                      #
# /endlessh                                                            #
#                                                                      #
########################################################################
```

### Change the port to listen (optional)

By default, the Endlessh-go instance binds to port 22 on all network interfaces. You can change the port by adding the following configuration to your `vars.yml` file:

```yaml
endlessh_container_host_bind_port: YOUR_PORT_NUMBER_HERE
```

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, the instance starts running on the server and listens to the specified port (port 22 by default).

You can customize how it works with the `endlessh_container_extra_arguments_custom` variable. For example, you can have it log to standard error instead of files by adding the following configuration:

```yaml
endlessh_container_extra_arguments_custom:
  - "-logtostderr"
```

See [this section](https://github.com/shizunge/endlessh-go/blob/main/README.md#usage) of the documentation for other available arguments.

### Integrate with Prometheus

Endlessh-go can natively expose metrics to Prometheus.

If you are looking for an integration, you can check out the MASH playbook. See [here](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/services/endlessh.md#integrating-with-prometheus) for more information.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu endlessh` (or how you/your playbook named the service, e.g. `mash-endlessh`).
