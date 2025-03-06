class HarnessDevx < Formula
  desc "Harness DevX Platform - Local Development Environment Setup"
  homepage "https://harness.io"
  url "https://github.com/muralikrishnagk/homebrew-harness/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "5412f4c476fdcff76947f9be258c18256c98ae50f29d087ed6dc00f184b221a8"
  version "1.0.0"
  license "PolyForm Free Trial 1.0.0"

  # Core dependencies
  depends_on "openjdk@17"
  depends_on "colima"
  depends_on "docker"
  depends_on "yq"
  depends_on "jq"
  depends_on "bazelisk"
  depends_on "mutagen-io/mutagen/mutagen"

  def install
    # Create necessary directories
    system "mkdir", "-p", "#{ENV["HOME"]}/.devx"
    system "mkdir", "-p", "#{ENV["HOME"]}/.sdkman"
    system "mkdir", "-p", "#{ENV["HOME"]}/.bazel_runner/output_base"
    system "mkdir", "-p", "#{ENV["HOME"]}/.bazel_runner/disk_cache"
    system "mkdir", "-p", "#{ENV["HOME"]}/.bazel_runner/repository_cache"
    system "mkdir", "-p", "#{ENV["HOME"]}/.colima/default"
    
    # Create default Colima configuration
    unless File.exist?("#{ENV["HOME"]}/.colima/default/colima.yaml")
      File.write("#{ENV["HOME"]}/.colima/default/colima.yaml", <<~EOS
        cpu: 8
        memory: 16
        disk: 100
        rosetta: false
        arch: aarch64
      EOS
      )
    end

    # Create default DevX configuration
    unless File.exist?("#{ENV["HOME"]}/.devx/localBuilder_config.yaml")
      File.write("#{ENV["HOME"]}/.devx/localBuilder_config.yaml", <<~EOS
        cpu: 8
        memory: 16
        disk: 100
        enable_checks: false
      EOS
      )
    end

    # Create setup script
    setup_script = <<~EOS
      #!/bin/bash
      set -e

      # Helper functions
      check_command() {
        if ! command -v "$1" &>/dev/null; then
          echo "Error: $1 is not installed. Please install it with: $2"
          exit 1
        fi
      }

      check_version() {
        local cmd="$1"
        local version="$2"
        local min_version="$3"
        if [ "$(printf '%s\\n%s' "$min_version" "$version" | sort -V | head -n1)" != "$min_version" ]; then
          echo "Error: $cmd version $version is lower than required version $min_version"
          exit 1
        fi
      }

      restart_colima() {
        echo "Restarting Colima to apply changes..."
        colima stop
        sleep 5
        if [ -f "Makefile" ] && grep -q "start-colima:" Makefile; then
          make start-colima
        else
          colima start --arch aarch64 --cpu 8 --memory 16 --disk 100 --runtime docker --mount-type 9p
        fi
        sleep 5
      }

      setup_docker_context() {
        echo "Setting up Docker context..."
        # Remove existing context if it exists
        docker context rm colima &>/dev/null || true
        
        # Install nerdctl
        if ! command -v nerdctl &>/dev/null; then
          echo "Installing nerdctl..."
          colima nerdctl install
        fi

        # Create and switch to colima context
        docker context create colima 2>/dev/null || true
        if ! docker context use colima; then
          echo "Error: Failed to switch to colima context. Attempting to fix..."
          restart_colima
          docker context use colima || {
            echo "Error: Still unable to switch to colima context. Please try running 'colima delete' and then 'harness-setup' again."
            exit 1
          }
        fi
      }

      echo "Setting up Harness DevX environment..."

      # Version checks
      check_command "docker" "brew install docker"
      check_command "colima" "brew install colima"
      check_command "git" "brew install git"

      DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',v')
      COLIMA_VERSION=$(colima version | head -n1 | awk '{print $2}')
      GIT_VERSION=$(git --version | awk '{print $3}')

      check_version "Docker" "$DOCKER_VERSION" "20.10.0"
      check_version "Colima" "$COLIMA_VERSION" "0.5.0"
      check_version "Git" "$GIT_VERSION" "2.0.0"

      # Install required casks
      echo "Installing required casks..."
      if ! brew list --cask google-cloud-sdk &>/dev/null; then
        brew install --cask google-cloud-sdk || {
          echo "Error: Failed to install google-cloud-sdk"
          exit 1
        }
      fi
      if ! brew list --cask intellij-idea-ce &>/dev/null; then
        brew install --cask intellij-idea-ce || true
      fi

      # Install SDKMAN and Java
      echo "Installing SDKMAN and Java..."
      if [ ! -d "$HOME/.sdkman" ]; then
        curl -s "https://get.sdkman.io" | bash || {
          echo "Error: Failed to install SDKMAN"
          exit 1
        }
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        sdk install java 17.0.7-tem || {
          echo "Error: Failed to install Java 17"
          exit 1
        }
      fi

      # Configure Google Cloud
      echo "Configuring Google Cloud..."
      if ! gcloud auth print-access-token &>/dev/null; then
        gcloud auth login || {
          echo "Error: Failed to authenticate with Google Cloud"
          exit 1
        }
        gcloud auth configure-docker || true
        gcloud auth configure-docker us-west1-docker.pkg.dev || true
      fi

      # Clone Harness Core repository if not already cloned
      echo "Setting up Harness Core repository..."
      HARNESS_CORE_DIR="$HOME/harness-ws/harness-core"
      if [ ! -d "$HARNESS_CORE_DIR" ]; then
        mkdir -p "$HOME/harness-ws"
        cd "$HOME/harness-ws"
        git clone https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core.git || {
          echo "Error: Failed to clone harness-core repository"
          exit 1
        }
      fi

      # Navigate to harness-core directory
      cd "$HARNESS_CORE_DIR" || {
        echo "Error: Failed to navigate to $HARNESS_CORE_DIR"
        exit 1
      }
      
      # Check if Makefile exists
      if [ ! -f "Makefile" ]; then
        echo "Error: Makefile not found in $HARNESS_CORE_DIR"
        exit 1
      fi

      # Set up Docker context and start Colima
      setup_docker_context

      # Check Docker daemon connection
      if ! docker info &>/dev/null; then
        echo "Error: Unable to connect to Docker daemon. Attempting to fix..."
        restart_colima
        if ! docker info &>/dev/null; then
          echo "Error: Still unable to connect to Docker daemon. Please try running 'colima delete' and then 'harness-setup' again."
          exit 1
        fi
      fi

      # Initialize the harness-core local devx container
      if grep -q "^init:" Makefile; then
        echo "Initializing harness-core..."
        make init || {
          echo "Error: Failed to initialize harness-core"
          echo "You may need to:"
          echo "1. Check your internet connection"
          echo "2. Ensure you have access to the required Docker images"
          echo "3. Run 'colima delete' to reset the container runtime"
          exit 1
        }
      else
        echo "Warning: 'make init' target not found in Makefile"
      fi

      echo "Setup complete!"
      echo
      echo "Next steps:"
      echo "1. Open IntelliJ IDEA"
      echo "2. Install the Bazel and Lombok plugins"
      echo "3. Import the harness-core project"
      echo
      echo "For detailed documentation, visit:"
      echo "https://harness.atlassian.net/wiki/spaces/BT/pages/22046113898/Local+DevX+Platform+README"
    EOS

    # Write setup script to a temporary file
    setup_script_path = buildpath/"harness-setup"
    setup_script_path.write(setup_script)
    setup_script_path.chmod(0755)

    # Install to prefix and create symlink
    prefix.install "harness-setup"
    bin.install_symlink prefix/"harness-setup"

    # Create a minimal README
    (share/"harness-devx").mkpath
    (share/"harness-devx/README.md").write <<~EOS
      # Harness DevX Platform

      This package sets up the Harness DevX development environment.
      
      ## System Requirements
      - MacOS Sonoma 14.5 or higher
      - Minimum 8 CPUs
      - 20 GB RAM
      - 100 GB Storage

      ## Usage
      Run the setup script after enabling Admin By Request or as Root:
      ```bash
      harness-setup
      ```

      ## Container Runtime Options
      1. Colima (recommended, configured by default)
         - Automatically configured with 8 CPU, 16GB RAM, 100GB disk
         - ARM64 native support (no Rosetta emulation)

      2. Docker Desktop
         - Configure resources: 8 CPU, 20GB RAM, 100GB disk minimum
         - Enable Rosetta emulation only for AMD images
         - Set context: docker context use docker-desktop

      3. Rancher Desktop
         - Configure resources: 8 CPU, 20GB RAM, 100GB disk minimum
         - Enable VZ and configure Rosetta as needed
         - Set context: docker context use rancher-desktop

      ## Documentation
      For detailed documentation, visit:
      https://harness.atlassian.net/wiki/spaces/BT/pages/22046113898/Local+DevX+Platform+README
    EOS
  end

  def caveats
    <<~EOS
      Important Notes:
      1. System Requirements:
         - MacOS Sonoma 14.5 or higher
         - Minimum 8 CPUs
         - 20 GB RAM
         - 100 GB Storage

      2. To complete setup:
         $ harness-setup

      3. Container Runtime Options:
         - Colima (recommended, configured by default)
         - Docker Desktop
         - Rancher Desktop

         For Docker Desktop or Rancher Desktop:
         - Ensure minimum resources (8 CPU, 20GB RAM, 100GB Storage)
         - Configure VM settings appropriately
         - Set Docker context: docker context use <runtime>

      4. Development Tools:
         - IntelliJ IDEA will be installed automatically
         - Remember to install the Bazel and Lombok plugins

      5. For detailed documentation:
         https://harness.atlassian.net/wiki/spaces/BT/pages/22046113898/Local+DevX+Platform+README

      If you encounter any issues, please contact Harness support.
    EOS
  end

  test do
    assert_predicate bin/"harness-setup", :exist?
    assert_predicate share/"harness-devx/README.md", :exist?
    system "colima", "version"
    system "docker", "--version"
    system "bazelisk", "version"
    system "java", "--version"
  end
end
