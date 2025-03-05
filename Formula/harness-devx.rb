class HarnessDevx < Formula
  desc "Harness DevX Platform - Local Development Environment Setup"
  homepage "https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core"
  head "https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core.git"
  version "1.0.0"
  license "PolyForm Free Trial 1.0.0"
  
  # Required dependencies
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

    # Install the harness-core repository
    system "git", "clone", "--depth", "1", "https://git.harness.io/vpCkHKsDSxK9_KYfjCTMKA/HarnessHCRInternalUAT/Harness_Code/harness-core.git", "#{prefix}/harness-core"

    # Create setup script
    (bin/"harness-setup").write <<~EOS
      #!/bin/bash
      set -e

      echo "Setting up Harness DevX environment..."

      # Install required casks
      brew install --cask google-cloud-sdk
      brew install --cask intellij-idea-ce

      # Configure Google Cloud
      echo "Configuring Google Cloud..."
      gcloud auth login
      gcloud auth configure-docker
      gcloud auth configure-docker us-west1-docker.pkg.dev

      # Start Colima
      echo "Starting Colima..."
      colima start

      # Initialize development environment
      echo "Initializing development environment..."
      cd #{prefix}/harness-core
      make init

      echo "Setup complete! Your Harness DevX environment is ready."
    EOS

    # Make the setup script executable
    chmod 0755, bin/"harness-setup"
  end

  def caveats
    <<~EOS
      Important Notes:
      1. To complete the setup, run:
         $ harness-setup

      2. System Requirements:
         - Minimum 8 CPUs
         - 20 GB RAM
         - 100 GB Storage

      3. Container Runtime:
         - This setup uses Colima by default
         - For Docker Desktop or Rancher Desktop, adjust settings accordingly

      4. Development Tools:
         - IntelliJ IDEA will be installed
         - Remember to install the Bazel and Lombok plugins

      5. For detailed documentation, visit:
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
