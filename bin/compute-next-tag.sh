#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Prints the tag that the currently checked out commit should be released as,
# or nothing at all if it does not warrant a release.
#
# Usage: bin/compute-next-tag.sh
#
# Tags look like `v<itzg/minecraft-server version>-<release>`, which is what
# this repository has always published (v2025.4.2-1 ... v2026.6.0-1):
#
# - if defaults/main.yml points at an image version that has never been
#   released, the release counter restarts at 0 (`v2026.8.2-0`)
# - otherwise the counter is incremented (`v2026.8.2-1`), but only if something
#   that actually affects the role has changed since the last release
#
# Determining the version from defaults/main.yml, rather than from the commit
# message of the pull request that got merged, makes the result independent of
# the order in which pull requests get merged, and lets any change to the role
# (bugfix, feature, dependency bump) release itself without a human tagging.
# The commit-message approach this replaced could only ever see Renovate's own
# commits: every hand-written change to this role went unreleased until someone
# noticed and tagged it by hand.

set -euo pipefail

repository_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$repository_path"

defaults_path='defaults/main.yml'

# Paths that shape the behavior of the role for its consumers. A commit
# touching only other paths (a README fix, CI configuration, Molecule tests)
# does not change what a playbook run does, and releasing it would only create
# churn in the repositories that consume this role.
role_defining_paths=(
	'defaults'
	'meta'
	'tasks'
	'templates'
)

# Anchored on `minecraft_docker_version:` so that neither the prose above it nor
# `minecraft_container_image_tag`, which is derived from it, can be mistaken for it.
version="$(sed -nE 's|^minecraft_docker_version:[[:space:]]*"?([^"[:space:]]+)"?.*$|\1|p' "$defaults_path" | head -n1)"

if [ -z "$version" ]; then
	echo >&2 "Could not determine the itzg/minecraft-server version from $defaults_path"
	exit 1
fi

# itzg/minecraft-server versions are `<year>.<month>.<patch>`, optionally
# followed by a flavour that selects a JRE or base image (`-java21`, `-alpine`,
# ...). Only the numeric part identifies a release of the image, so the flavour
# is left out of the tag: it keeps the tags comparable with the ones this
# repository already published, and it keeps them stable if the role ever has to
# move between flavours (which is a change to the role, released by the counter,
# not a new upstream version).
if [[ ! "$version" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+) ]]; then
	echo >&2 "Version '$version' from $defaults_path is not a <year>.<month>.<patch> version"
	exit 1
fi

tag_prefix="v${BASH_REMATCH[1]}-"

# Of all releases of this version, the highest release number. Sorted
# numerically, so that -10 is recognized as newer than -9.
last_release="$(git tag --list "${tag_prefix}*" | sed -e "s|^${tag_prefix}||" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [ -z "$last_release" ]; then
	echo >&2 "Version $version has never been released"
	echo "${tag_prefix}0"
	exit 0
fi

previous_tag="${tag_prefix}${last_release}"

if git diff --quiet "$previous_tag" HEAD -- "${role_defining_paths[@]}"; then
	echo >&2 "Nothing affecting the role has changed since $previous_tag"
	exit 0
fi

echo >&2 "The role has changed since $previous_tag"
echo "${tag_prefix}$((last_release + 1))"
