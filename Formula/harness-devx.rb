class HarnessDevx < Formula
  desc "Harness DevX Platform - Local Development Environment Setup"
  homepage "https://harness.io"
  url "https://github.com/muralikrishnagk/homebrew-harness/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "dd3aae34d2b42500cdc4a0cb1b327a0113071fd128a42f4f77d45940b8c0084e"
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
    (bin/"harness-setup").write <<~EOS
      #!/bin/bash
      set -e

      echo "Setting up Harness DevX environment..."

      # Install required casks
      echo "Installing required casks..."
      if ! brew list --cask google-cloud-sdk &>/dev/null; then
        brew install --cask google-cloud-sdk || true
      fi
      if ! brew list --cask intellij-idea-ce &>/dev/null; then
        brew install --cask intellij-idea-ce || true
      fi
      if ! brew list --cask colima &>/dev/null; then
        brew install --cask colima || true
        # Set Docker context and start Colima
       echo "Setting Docker context to Colima..."
       docker context use colima
fi

      # Install SDKMAN and Java
      echo "Installing SDKMAN and Java..."
      if [ ! -d "$HOME/.sdkman" ]; then
        curl -s "https://get.sdkman.io" | bash
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        sdk install java 17.0.7-tem
      fi

      # Configure Google Cloud
      echo "Configuring Google Cloud..."
      if ! gcloud auth print-access-token &>/dev/null; then
        gcloud auth login
        gcloud auth configure-docker
        gcloud auth configure-docker us-west1-docker.pkg.dev
      fi

      # Clone Harness Core repository if not already cloned
      echo "Setting up Harness Core repository..."
      HARNESS_CORE_DIR="$HOME/harness-ws/harness-core"
      if [ ! -d "$HARNESS_CORE_DIR" ]; then
        mkdir -p "$HOME/harness-ws"
        cd "$HOME/harness-ws"
        git clone https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core.git
        cd harness-core 
      fi

    
      # Start Colima using make command if context is colima, otherwise use direct command
      echo "Starting Colima..."
      if [ "$(docker context show)" = "colima" ]; then
        cd "$HARNESS_CORE_DIR"
        make start-colima
      fi

      # Initialize the harness-core local devx container
      make init

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

    # Make the setup script executable
    chmod 0755, bin/"harness-setup"

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
