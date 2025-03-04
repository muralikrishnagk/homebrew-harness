class HarnessDevx < Formula
  desc "Harness DevX Platform - Local Development Environment Setup"
  homepage "https://harness.io"
  version "1.0.0"
  
  # Required dependencies
  depends_on "openjdk@17"
  depends_on "colima"
  depends_on "docker"
  depends_on "yq"
  depends_on "jq"
  depends_on "bazelisk"
  depends_on "mutagen-io/mutagen/mutagen"
  depends_on "google-cloud-sdk"

  # Recommended cask dependencies
  depends_on cask: "intellij-idea-ce"

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

    prefix.install Dir["*"]
  end

  def post_install
    # Configure Google Cloud Docker authentication
    system "gcloud", "auth", "configure-docker"
    system "gcloud", "auth", "configure-docker", "us-west1-docker.pkg.dev"

    # Set Docker context to Colima
    system "docker", "context", "use", "colima"

    ohai "Installation Complete!"
    ohai "Next Steps:"
    puts <<~EOS
      1. Install IntelliJ Plugins:
         - Open IntelliJ IDEA
         - Go to Settings/Preferences > Plugins
         - Install "Bazel" and "Lombok" plugins

      2. Configure Google Cloud:
         $ gcloud auth login

      3. Start Colima (if not already running):
         $ colima start

      4. Initialize the development environment:
         $ cd YOUR_HARNESS_CORE_DIRECTORY
         $ make init

      System Requirements:
      - Minimum 8 CPUs
      - 20 GB RAM
      - 100 GB Storage

      For detailed documentation, visit:
      https://harness.atlassian.net/wiki/spaces/BT/pages/22046113898/Local+DevX+Platform+README
    EOS
  end

  test do
    system "colima", "version"
    system "docker", "--version"
    system "bazelisk", "version"
    system "java", "--version"
  end

  def caveats
    <<~EOS
      Important Notes:
      1. This formula installs OpenJDK 17. If you prefer to use SDKman for Java management:
         $ curl -s "https://get.sdkman.io" | bash
         $ sdk install java 17.0.7-tem

      2. For ARM-based Macs:
         - Rosetta emulation is disabled by default
         - This is the recommended setup for optimal performance

      3. Container Runtime Options:
         - This formula sets up Colima as the default container runtime
         - You can also use Docker Desktop or Rancher Desktop
         - Ensure your chosen runtime has sufficient resources allocated

      4. Docker Context:
         - Currently set to use Colima
         - To check available contexts: docker context ls
         - To change context: docker context use <context-name>

      If you encounter any issues, please refer to the documentation or contact Harness support.
    EOS
  end
end
