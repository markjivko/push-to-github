#!/bin/sh -l

set -e  # stop execution on failure
set -u  # fail on undefined error

echo "[+] Action start"
SOURCE_DIRECTORY="${1}"
TARGET_GITHUB_USERNAME="${2}"
TARGET_GITHUB_REPOSITORY="${3}"
TARGET_GITHUB_BRANCH="${4}"
TARGET_DIRECTORY="${5}"
COMMIT_EMAIL="${6}"
COMMIT_NAME="${7}"
COMMIT_MESSAGE="${8}"
GITHUB_SERVER="${9}"

if [ -z "$COMMIT_NAME" ]
then
	COMMIT_NAME="$TARGET_GITHUB_USERNAME"
fi

if [ -n "${SSH_DEPLOY_KEY:=}" ]
then
	# @see https://github.com/leigholiver/commit-with-deploy-key/blob/main/entrypoint.sh
	echo "[+] Using SSH_DEPLOY_KEY"
	mkdir --parents "$HOME/.ssh"
	DEPLOY_KEY_FILE="$HOME/.ssh/deploy_key"

	echo "${SSH_DEPLOY_KEY}" > "$DEPLOY_KEY_FILE"
	chmod 600 "$DEPLOY_KEY_FILE"
	SSH_KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
	ssh-keyscan -H "$GITHUB_SERVER" > "$SSH_KNOWN_HOSTS_FILE"
	export GIT_SSH_COMMAND="ssh -i "$DEPLOY_KEY_FILE" -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"
	GIT_CMD_REPOSITORY="git@$GITHUB_SERVER:$TARGET_GITHUB_USERNAME/$TARGET_GITHUB_REPOSITORY.git"
elif [ -n "${API_TOKEN_GITHUB:=}" ]
then
	echo "[+] Using API_TOKEN_GITHUB"
	GIT_CMD_REPOSITORY="https://$TARGET_GITHUB_USERNAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$TARGET_GITHUB_USERNAME/$TARGET_GITHUB_REPOSITORY.git"
else
	echo "::error::API_TOKEN_GITHUB and SSH_DEPLOY_KEY are empty. Please fill one (recommended the SSH_DEPLOY_KEY)"
	exit 1
fi


CLONE_DIR=$(mktemp -d)

echo "[+] Git version"
git --version

echo "[+] Cloning destination git repository $TARGET_GITHUB_REPOSITORY"
git config --global user.email "$COMMIT_EMAIL"
git config --global user.name "$COMMIT_NAME"

{
	git clone --single-branch --depth 1 --branch "$TARGET_GITHUB_BRANCH" "$GIT_CMD_REPOSITORY" "$CLONE_DIR"
} || {
	echo "::error::Could not clone the destination repository. Command:"
	echo "::error::git clone --single-branch --branch $TARGET_GITHUB_BRANCH $GIT_CMD_REPOSITORY $CLONE_DIR"
	echo "::error::(Note that if they exist COMMIT_NAME and API_TOKEN_GITHUB are redacted by GitHub)"
	echo "::error::Please verify that the target repository exists AND that it contains the destination branch name, and is accesible by the API_TOKEN_GITHUB OR SSH_DEPLOY_KEY"
	exit 1
}
ls -la "$CLONE_DIR"

TEMP_DIR=$(mktemp -d)

# Save the .git folder
mv "$CLONE_DIR/.git" "$TEMP_DIR/.git"

# Prepare the target
ABSOLUTE_TARGET_DIRECTORY="$CLONE_DIR/$TARGET_DIRECTORY/"

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

echo "[+] Listing $SOURCE_DIRECTORY"
ls "$SOURCE_DIRECTORY"

echo "[+] Checking if local $SOURCE_DIRECTORY exist"
if [ ! -d "$SOURCE_DIRECTORY" ]
then
	echo "::error::Source directory $SOURCE_DIRECTORY does not exist"
	echo "::error::This directory needs to exist when this action is executed"
	exit 1
fi

echo "[+] Copying contents of source directory $SOURCE_DIRECTORY to $TARGET_DIRECTORY in GitHub repo $TARGET_GITHUB_REPOSITORY"
cp -ra "$SOURCE_DIRECTORY"/. "$CLONE_DIR/$TARGET_DIRECTORY"
cd "$CLONE_DIR"

echo "[+] Listing Current Directory"
ls -la

ORIGIN_COMMIT="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
COMMIT_MESSAGE="${COMMIT_MESSAGE/ORIGIN_COMMIT/$ORIGIN_COMMIT}"
COMMIT_MESSAGE="${COMMIT_MESSAGE/\$GITHUB_REF/$GITHUB_REF}"

echo "[+] Set directory is safe ($CLONE_DIR)"
git config --global --add safe.directory "$CLONE_DIR"

echo "[+] Adding all changes"
git add .

echo "[+] Git status:"
git status

echo "[+] Git diff-index:"
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] Pushing to branch $TARGET_GITHUB_BRANCH of $TARGET_GITHUB_REPOSITORY..."
git push "$GIT_CMD_REPOSITORY" --set-upstream "$TARGET_GITHUB_BRANCH"