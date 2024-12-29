#!/usr/bin/env python3
"""
single-updater

Usage: single-updater --base-branch BRANCH --element ELEMENT

This is a wrapper for https://gitlab.com/BuildStream/infrastructure/gitlab-merge-request-generator
to merge all updates in a single branch.

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

import re
import subprocess
import argparse
import logging
import shutil
import datetime

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")


def is_cmd(cmd):
    return shutil.which(cmd) is not None


def is_git_dir():
    return (
        subprocess.run(
            ["git", "rev-parse"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def is_dirty():
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        text=True,
    )
    return bool(result.stdout.strip())


def get_local_branches():
    result = subprocess.run(
        ["git", "branch"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    return [line.strip().lstrip("* ").strip() for line in result.stdout.splitlines()]


def delete_branch(branch):
    return (
        subprocess.run(
            ["git", "branch", "-D", branch],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def run_updater(branch, element):
    subprocess.run(
        [
            "auto_updater",
            f"--base_branch={branch}",
            "--nobuild",
            "--overwrite",
            "--push",
            "--shuffle-branches",
            "--on_track_error=continue",
            element,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    # It fails due to too many random tracking errors
    # that aren't handled upstream. But it can still create
    # branches with updates as it goes which are useful
    return True


def create_branch(base_branch):
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    branch_name = f"updates/{timestamp}"
    success = (
        subprocess.run(
            ["git", "checkout", "-b", branch_name, base_branch],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        ).returncode
        == 0
    )
    return branch_name if success else None


def reformat_commit_message(commit_message):
    pattern = r"Update elements/(components|include|abi|bootstrap|extensions)/(.*?)[.](bst|yml) to (.*)"
    match = re.match(pattern, commit_message)
    if match:
        element_name = match.group(2)
        updated_version = match.group(4)
        return f"{element_name}: Update to {updated_version}"
    else:
        return commit_message


def cherry_pick_top_commit(branches, new_branch):
    all_successful = True
    for branch in branches:
        checkout_branch(branch)
        result = subprocess.run(
            ["git", "log", "--format=%H", "-n", "1"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
        )
        top_commit = result.stdout.strip()
        if top_commit:
            checkout_branch(new_branch)
            subprocess.run(
                ["git", "cherry-pick", top_commit],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            commit_message_result = subprocess.run(
                ["git", "log", "-1", "--pretty=%B"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                text=True,
            )
            commit_message = commit_message_result.stdout.strip()
            new_message = reformat_commit_message(commit_message)
            subprocess.run(
                ["git", "commit", "--amend", "-m", new_message],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        else:
            all_successful = False
    return all_successful


def checkout_branch(branch):
    return (
        subprocess.run(
            ["git", "checkout", branch],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def validate_environment(element_name, base_branch):
    validations = [
        (is_cmd("git"), "Unable to find git in PATH"),
        (is_cmd("auto_updater"), "Unable to find auto_updater in PATH"),
        (is_git_dir(), "Current directory is not a git repository"),
        (not is_dirty(), "The repository is dirty"),
    ]
    for valid, msg in validations:
        if not valid:
            logging.error(msg)
            return False
    return True


def cleanup(branches, base_branch, branch_regex):
    checkout_branch(base_branch)
    clean_branches = [branch for branch in branches if re.match(branch_regex, branch)]
    for branch in clean_branches:
        if not delete_branch(branch):
            logging.error(f"Failed to delete local branch: {branch}")
            return False
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Run auto_updater and merge changes in a single branch. A wrapper for gitlab-merge-request-generator to merge all updates in a single branch."
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Do not delete auto_updater local branches",
    )
    parser.add_argument(
        "--base-branch",
        type=str,
        required=True,
        help="Specify the base branch",
    )
    parser.add_argument(
        "--element",
        type=str,
        required=True,
        help="Specify the element auto_updater will track",
    )
    args = parser.parse_args()

    branch_regex = rf"^update/(components|include|abi|bootstrap|extensions)_.*[.](bst|yml)-diff_md5-.*-for-({args.base_branch})$"

    if not validate_environment(args.element, args.base_branch):
        return 1

    branches = get_local_branches()
    if not branches:
        logging.error("No branches found")
        return 1

    if not args.no_cleanup and not cleanup(branches, args.base_branch, branch_regex):
        return 1

    if run_updater(args.base_branch, args.element):
        if not is_dirty():
            new_branch = create_branch(args.base_branch)
            if new_branch:
                new_branches = [
                    branch for branch in branches if re.match(branch_regex, branch)
                ]
                if not cherry_pick_top_commit(new_branches, new_branch):
                    logging.error("Failed to cherry-pick commit")
                    return 1
            else:
                logging.error("Failed to create new branch")
                return 1
        else:
            logging.error(
                "The repository is dirty after running auto_updater"
                if is_dirty()
                else "Failed to checkout new branch"
            )
            return 1
    else:
        logging.error("auto_updater failed")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
