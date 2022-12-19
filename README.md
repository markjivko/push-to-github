# Push to GitHub

GitHub action to push directory to another GitHub repository

## Usage

You need to provide the target repository's private key as a secret.

### Using GITHUB_SSH_KEY

- Create an SSH key-pair on your machine
- Add the **public key** to your target repository as a **deploy key** with write access
- Add the **private key** to your source repository as a **secret** (for example `MY_GITHUB_PRIVATE_SSH_KEY`)

```yaml
uses: markjivko/push-to-github@main
env:
  GITHUB_SSH_KEY: ${{ secrets.MY_GITHUB_PRIVATE_SSH_KEY }}
with:
  source-directory: "out"
  target-github-username: "my-user"
  target-github-repository: "my-repo"
  target-github-branch: "main"
  commit-email: "111111111+user@users.noreply.github.com"
  commit-name: "John Doe"
  commit-message: ${{ github.event.head_commit.message }}
```
