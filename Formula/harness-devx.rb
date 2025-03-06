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

      echo "Setting up Harness DevX environment..."

      # Install required casks
      echo "Installing required casks..."
      if ! brew list --cask google-cloud-sdk &>/dev/null; then
        brew install --cask google-cloud-sdk || true
      fi
      if ! brew list --cask intellij-idea-ce &>/dev/null; then
        brew install --cask intellij-idea-ce || true
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
      fi

      # Navigate to harness-core directory
      cd "$HARNESS_CORE_DIR" || exit 1
      
      # Check if Makefile exists
      if [ ! -f "Makefile" ]; then
        echo "Error: Makefile not found in $HARNESS_CORE_DIR"
        exit 1
      fi

      # Check if Colima is installed
      if ! command -v colima &>/dev/null; then
        echo "Error: Colima is not installed. Installing Colima now"
        brew install colima || true
      elif colima status &>/dev/null; then
      # Stop Colima if running
        echo "Stopping Colima..."
        colima stop
      fi

      # Set up Docker context
      echo "Setting up Docker context..."
      docker context rm colima &>/dev/null || true
      colima nerdctl install
      docker context use colima || true

      # Start Colima based on Makefile target
      echo "Starting Colima..."
      if grep -q "start-colima:" Makefile; then
        make start-colima
      else
        colima start --cpu 8 --memory 16 --disk 100 --arch aarch64
      fi

      # Initialize the harness-core local devx container if make init target exists
      if grep -q "^init:" Makefile; then
        echo "Initializing harness-core..."
        make init
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
