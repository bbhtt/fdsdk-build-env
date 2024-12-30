#!/usr/bin/env python3
"""
single-updater

Usage: single-updater --base-branch BRANCH --element ELEMENT

This is a wrapper for https://gitlab.com/BuildStream/infrastructure/gitlab-merge-request-generator
to cherry-pick all updates in a single branch.

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"""

import argparse
import datetime
import logging
import re
import shutil
import subprocess
from subprocess import CompletedProcess

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")


def run_command(
    command: list[str],
    check: bool = False,
    capture_output: bool = False,
    text: bool = True,
) -> CompletedProcess:
    return subprocess.run(
        command,
        stdout=subprocess.PIPE if capture_output else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture_output else subprocess.DEVNULL,
        check=check,
        text=text,
    )


def is_cmd_present(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def is_git_dir() -> bool:
    return run_command(["git", "rev-parse"]).returncode == 0


def is_dirty() -> bool:
    result = run_command(["git", "status", "--porcelain"], capture_output=True)
    return bool(result.stdout.strip())


def get_local_branches() -> list[str]:
    result = run_command(["git", "branch"], capture_output=True)
    return [line.strip().lstrip("* ").strip() for line in result.stdout.splitlines()]


def delete_branch(branch: str) -> bool:
    return run_command(["git", "branch", "-D", branch]).returncode == 0


def run_updater(branch: str, element: str) -> None:
    run_command(
        [
            "auto_updater",
            f"--base_branch={branch}",
            "--nobuild",
            "--overwrite",
            "--shuffle-branches",
            "--on_track_error=continue",
            element,
        ]
    )


def create_branch(base_branch: str) -> str | None:
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d%H%M%S")
    branch_name = f"updates/{base_branch}/{timestamp}"
    success = (
        run_command(["git", "checkout", "-b", branch_name, base_branch]).returncode == 0
    )
    return branch_name if success else None


def reformat_commit_message(commit_message: str) -> str:
    pattern = r"Update elements/(components|include|abi|bootstrap|extensions)/(.*?)[.](bst|yml) to (.*)"
    matched = re.match(pattern, commit_message)
    if matched:
        element_name = (
            matched.group(2).split("/")[-1]
            if "/" in matched.group(2)
            else matched.group(2)
        )
        updated_version = matched.group(4)
        return f"{element_name}: Update to {updated_version}"
    return commit_message


def cherry_pick_top_commit(branch_list: list[str], single_branch: str) -> None:
    for branch in branch_list:
        checkout_branch(branch)
        result = run_command(["git", "rev-parse", "HEAD"], capture_output=True)
        top_commit = result.stdout.strip()
        if top_commit:
            checkout_branch(single_branch)
            run_command(["git", "cherry-pick", top_commit])
            commit_message_result = run_command(
                ["git", "log", "-1", "--pretty=%B"], capture_output=True
            )
            commit_message = commit_message_result.stdout.strip()
            new_message = reformat_commit_message(commit_message)
            run_command(["git", "commit", "--amend", "-m", new_message])


def checkout_branch(branch: str) -> bool:
    return run_command(["git", "checkout", branch]).returncode == 0


def validate_environment() -> bool:
    validations = [
        (is_cmd_present("git"), "Unable to find git in PATH"),
        (is_cmd_present("bst"), "Unable to find bst in PATH"),
        (is_cmd_present("auto_updater"), "Unable to find auto_updater in PATH"),
        (is_git_dir(), "Current directory is not a git repository"),
        (not is_dirty(), "The repository is dirty"),
    ]
    for valid, msg in validations:
        if not valid:
            logging.error(msg)
            return False
    return True


def cleanup_branches(branches: list[str], base_branch: str, branch_regex: str) -> None:
    checkout_branch(base_branch)
    clean_branches = [branch for branch in branches if re.match(branch_regex, branch)]
    for branch in clean_branches:
        delete_branch(branch)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Run auto_updater and merge changes in a single branch. "
            "A wrapper for gitlab-merge-request-generator to cherry-pick "
            "all updates in a single branch."
        )
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Do not delete auto_updater local branches",
    )
    parser.add_argument(
        "--base-branch", type=str, required=True, help="Specify the base branch"
    )
    parser.add_argument(
        "--element",
        type=str,
        required=True,
        help="Specify the element auto_updater will track",
    )
    args = parser.parse_args()

    branch_regex = (
        rf"^update/"
        r"(components|include|abi|bootstrap|extensions)_.*[.]"
        r"(bst|yml)"
        rf"-diff_md5-.*-for-{args.base_branch}$"
    )

    if not validate_environment():
        return 1

    branches = get_local_branches()
    if not branches:
        logging.error("No local git branches found")
        return 1

    if not args.no_cleanup:
        cleanup_branches(branches, args.base_branch, branch_regex)

    run_updater(args.base_branch, args.element)

    if not is_dirty():
        single_branch = create_branch(args.base_branch)
        if single_branch:
            updater_branches = [
                branch
                for branch in get_local_branches()
                if re.match(branch_regex, branch)
            ]
            cherry_pick_top_commit(updater_branches, single_branch)
            if not args.no_cleanup:
                cleanup_branches(get_local_branches(), args.base_branch, branch_regex)
            if not checkout_branch(single_branch):
                logging.error("Failed to checkout unified branch")
                return 1
        else:
            logging.error("Failed to create new branch")
            return 1
    else:
        logging.error("The repository is dirty after running auto_updater")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
