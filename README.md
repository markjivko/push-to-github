# Push to GitHub

GitHub action to push directory to another GitHub repository

## Usage

You need to provide the target repository's private key as a secret.

### Using GITHUB_SSH_KEY

- Create an SSH key-pair on your machine
- Add the **public key** to your target repository
- Add the **private key** to your source repository as a **secret** (for example `GITHUB_TARGET_SSH_KEY`)

```yaml
uses: markjivko/push-to-github@main
env:
  GITHUB_SSH_KEY: ${{ secrets.GITHUB_TARGET_SSH_KEY }}
with:
  source-directory: "out"
  target-directory: "src"
  target-github-username: "user"
  target-github-repository: "repo"
  target-github-branch: "main"
```
