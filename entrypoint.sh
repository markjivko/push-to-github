#!/bin/sh -l

set -e  # stop execution on failure
set -u  # fail on undefined error

echo "[+] Action start"
INPUT_SOURCE_DIRECTORY="${1}"
INPUT_TARGET_GITHUB_USERNAME="${2}"
INPUT_TARGET_GITHUB_REPOSITORY="${3}"
INPUT_TARGET_GITHUB_BRANCH="${4}"
INPUT_TARGET_DIRECTORY="${5}"
INPUT_COMMIT_EMAIL="${6}"
INPUT_COMMIT_NAME="${7}"
INPUT_COMMIT_MESSAGE="${8}"
INPUT_GITHUB_SERVER="${9}"

if [ -z "$INPUT_COMMIT_NAME" ]
then
	INPUT_COMMIT_NAME="$INPUT_TARGET_GITHUB_USERNAME"
fi

if [ -n "${GITHUB_SSH_KEY:=}" ]
then
	# @see https://github.com/leigholiver/commit-with-deploy-key/blob/main/entrypoint.sh
	echo "[+] Using GITHUB_SSH_KEY"
	mkdir --parents "$HOME/.ssh"
	SSH_DEPLOY_KEY_FILE="$HOME/.ssh/deploy_key"

	echo "${GITHUB_SSH_KEY}" > "$SSH_DEPLOY_KEY_FILE"
	chmod 600 "$SSH_DEPLOY_KEY_FILE"
	SSH_KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
	ssh-keyscan -H "$INPUT_GITHUB_SERVER" > "$SSH_KNOWN_HOSTS_FILE"
	export GIT_SSH_COMMAND="ssh -i "$SSH_DEPLOY_KEY_FILE" -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"
	GIT_CMD_REPOSITORY="git@$INPUT_GITHUB_SERVER:$INPUT_TARGET_GITHUB_USERNAME/$INPUT_TARGET_GITHUB_REPOSITORY.git"
else
	echo "::error::GITHUB_SSH_KEY is empty"
	exit 1
fi


CLONE_DIR=$(mktemp -d)

echo "[+] Git version"
git --version

echo "[+] Cloning destination git repository $INPUT_TARGET_GITHUB_REPOSITORY"
git config --global user.email "$INPUT_COMMIT_EMAIL"
git config --global user.name "$INPUT_COMMIT_NAME"

{
	git clone --single-branch --depth 1 --branch "$INPUT_TARGET_GITHUB_BRANCH" "$GIT_CMD_REPOSITORY" "$CLONE_DIR"
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $INPUT_TARGET_GITHUB_BRANCH $GIT_CMD_REPOSITORY $CLONE_DIR"
	echo "::error::Please verify that the target repository exists AND that it contains the destination branch name, and is accesible by GITHUB_SSH_KEY"
	exit 1
}
ls -la "$CLONE_DIR"

TEMP_DIR=$(mktemp -d)

# Save the .git folder
mv "$CLONE_DIR/.git" "$TEMP_DIR/.git"

# Prepare the target
ABSOLUTE_TARGET_DIRECTORY="$CLONE_DIR/$INPUT_TARGET_DIRECTORY/"

echo "[+] Deleting $ABSOLUTE_TARGET_DIRECTORY"
rm -rf "$ABSOLUTE_TARGET_DIRECTORY"

echo "[+] Creating (now empty) $ABSOLUTE_TARGET_DIRECTORY"
mkdir -p "$ABSOLUTE_TARGET_DIRECTORY"

echo "[+] Listing Current Directory"
ls -al

echo "[+] Listing root"
ls -al /

# Restore the .git folder
mv "$TEMP_DIR/.git" "$CLONE_DIR/.git"

echo "[+] Listing $INPUT_SOURCE_DIRECTORY"
ls "$INPUT_SOURCE_DIRECTORY"

echo "[+] Checking if local $INPUT_SOURCE_DIRECTORY exist"
if [ ! -d "$INPUT_SOURCE_DIRECTORY" ]
then
	echo "::error::Source directory $INPUT_SOURCE_DIRECTORY does not exist"
	echo "::error::This directory needs to exist when this action is executed"
	exit 1
fi

echo "[+] Copying contents of source directory $INPUT_SOURCE_DIRECTORY to $INPUT_TARGET_DIRECTORY in GitHub repo $INPUT_TARGET_GITHUB_REPOSITORY"
cp -ra "$INPUT_SOURCE_DIRECTORY"/. "$CLONE_DIR/$INPUT_TARGET_DIRECTORY"
cd "$CLONE_DIR"

echo "[+] Listing Current Directory"
ls -la

echo "[+] Set directory is safe ($CLONE_DIR)"
git config --global --add safe.directory "$CLONE_DIR"

echo "[+] Adding all changes"
git add .

echo "[+] Git status:"
git status

echo "[+] Git diff-index:"
git diff-index --quiet HEAD || git commit --message "$INPUT_COMMIT_MESSAGE"

echo "[+] Pushing to branch $INPUT_TARGET_GITHUB_BRANCH of $INPUT_TARGET_GITHUB_REPOSITORY..."
git push "$GIT_CMD_REPOSITORY" --set-upstream "$INPUT_TARGET_GITHUB_BRANCH"
