#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Endlessh 2026.0730.0 which has already
# seen two releases of it (v2026.0730.0-0 and v2026.0730.0-1).
#
# The defaults file is deliberately hostile. Besides the leaf literal that the
# script is supposed to key on, it carries a commented-out older value and a
# Jinja-derived tag that reads the literal back - both of which would produce a
# different (and wrong) answer if they were matched instead.
#
# The release history is hostile too, and is the one this repository really has:
# `endlessh_version` used to be a rolling `2026` tag, so releases named
# `v2026-0` and `v2026-1` sit alongside the dated `v2026.0730.0-*` ones. The two
# families must never be mistaken for one another in either direction.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	{
		printf '# renovate: datasource=docker depName=shizunge/endlessh-go\n'
		printf '# endlessh_version: 2025.0914.0\n'
		printf 'endlessh_version: 2026.0730.0\n'
		printf 'endlessh_container_image_tag: "{{ endlessh_version }}"\n'
		printf 'endlessh_container_image_self_build_repo_version: "{{ endlessh_version }}"\n'
	} > defaults/main.yml

	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v2026-$release_number"
		git tag "v2026.0730.0-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^endlessh_version: 2026.0730.0|endlessh_version: 2026.0801.0|' defaults/main.yml"
revert_version="sed -i 's|^endlessh_version: 2026.0801.0|endlessh_version: 2026.0730.0|' defaults/main.yml"
roll_back_to_rolling_version="sed -i 's|^endlessh_version: 2026.0730.0|endlessh_version: 2026|' defaults/main.yml"
edit_decoys="sed -i 's|^# endlessh_version: 2025.0914.0|# endlessh_version: 2024.1106.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v2026.0801.0-0 "$(merge "$bump_version")"
expect 'task edit'    v2026.0801.0-1 "$(merge "$edit_task")"
expect 'template'     v2026.0801.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v2026.0730.0-2 "$(merge "$edit_task")"
expect 'version bump' v2026.0801.0-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''               "$(merge "$edit_readme")"
expect 'a script' ''               "$(merge "$edit_script")"
expect 'a task'   v2026.0730.0-2   "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v2026.0730.0-$release_number"
done
expect 'a task' v2026.0730.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v2026.0730.0-1 already published, so there
# is nothing new to release.
expect 'a revert' ''                "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v2026.0730.0-2 "$(merge "$revert_version && $edit_task")"

# `v2026-1` is a real tag in this repository, left over from when the version
# was a rolling `2026` tag. It must not be read as a release of 2026.0730.0.
scenario 'A dated version is not released off the rolling version history'
expect 'a task' v2026.0730.0-2 "$(merge "$edit_task")"

# And the other way around: going back to the rolling tag must continue that
# tag's own counter rather than the dated one's.
scenario 'The rolling version continues its own release history'
expect 'roll back' v2026-2 "$(merge "$roll_back_to_rolling_version")"

# Neither the commented-out older value nor the two Jinja-derived lines that
# read the version back may be mistaken for the version itself.
scenario 'Decoy version lines are ignored'
expect 'decoy edit' v2026.0730.0-2 "$(merge "$edit_decoys")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
