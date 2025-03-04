# Harness Homebrew Tap

This is the official Homebrew tap for Harness development tools.

## Available Formulae

### harness-devx

A formula to set up the Harness DevX Platform local development environment. This formula installs and configures all necessary dependencies for developing with Harness.

#### Installation

```bash
# First, add the tap
brew tap harness/harness /Users/muralikrishnag/harness-ws/homebrew-harness

# Then install the formula
brew install harness-devx
```

#### What it installs

- OpenJDK 17
- Colima (container runtime)
- Docker
- Bazelisk
- YQ and JQ
- Mutagen
- Google Cloud SDK
- IntelliJ Community Edition

#### System Requirements

- MacOS Sonoma 14.5 or higher
- Minimum 8 CPUs
- 20 GB RAM
- 100 GB Storage

For more information, visit the [Local DevX Platform README](https://harness.atlassian.net/wiki/spaces/BT/pages/22046113898/Local+DevX+Platform+README)
