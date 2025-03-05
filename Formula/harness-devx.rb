class HarnessDevx < Formula
  desc "Harness DevX Platform - Local Development Environment Setup"
  homepage "https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core"
  url "https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core/-/raw/main/README.md"
  version "1.0.0"
  license "PolyForm Free Trial 1.0.0"

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

      # Install SDKMAN and Java
      echo "Installing SDKMAN and Java..."
      curl -s "https://get.sdkman.io" | bash
      source "$HOME/.sdkman/bin/sdkman-init.sh"
      sdk install java 17.0.7-tem

      # Install required casks
      echo "Installing required casks..."
      brew install --cask google-cloud-sdk
      brew install --cask intellij-idea-ce

      # Configure Google Cloud
      echo "Configuring Google Cloud..."
      gcloud auth login
      gcloud auth configure-docker
      gcloud auth configure-docker us-west1-docker.pkg.dev

      # Start and configure Colima
      echo "Starting Colima..."
      colima start

      # Set Docker context
      echo "Setting Docker context to Colima..."
      docker context use colima

      # Clone Harness Core repository
      echo "Cloning Harness Core repository..."
      cd "$HOME/harness-ws" || mkdir -p "$HOME/harness-ws"
      git clone https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core.git
      cd harness-core

      # Initialize the development environment
      echo "Initializing development environment..."
      make init

      echo "Setup complete!"
      echo "Next steps:"
      echo "1. Open IntelliJ IDEA"
      echo "2. Install the Bazel and Lombok plugins"
      echo "3. Import the harness-core project"
    EOS

    # Make the setup script executable
    chmod 0755, bin/"harness-setup"

    # Create a minimal README
    (share/"harness-devx").mkpath
    (share/"harness-devx/README.md").write <<~EOS
      # Harness DevX Platform

      This package sets up the Harness DevX development environment.
      
      ## Usage

      Run the setup script:
      ```bash
      harness-setup
      ```

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
    system "#{bin}/harness-setup", "--help"
    system "colima", "version"
    system "docker", "--version"
    system "bazelisk", "version"
    system "java", "--version"
  end
end
