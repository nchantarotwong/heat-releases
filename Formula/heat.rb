class Heat < Formula
  desc "AI-authored programming language and policy-checked MCP builder"
  homepage "https://github.com/nchantarotwong/heat-releases"
  version "0.9.10"

  depends_on "node"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.9.10/heat-darwin-arm64.tar.gz"
      sha256 "49141fb29c5bd01287cc5c2bcd8a8a631542aff86f82b64e1b2a997d13d3d2a6"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.9.10/heat-linux-arm64.tar.gz"
      sha256 "a37f8a6a5dd2a2a91bb9b7b4cd96032c5da44efa635307e86ecb7c0d115164af"
    else
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.9.10/heat-linux-x86_64.tar.gz"
      sha256 "c71577fd851ce692dc5ea90e6d8986ceb4b424b269381480ae7b328bf1225236"
    end
  end

  def install
    libexec.install Dir["*"]
    stdlib = libexec/"bootstrap/stdlib"
    bridge = libexec/"bootstrap/runtime/playwright_bridge.js"
    network_proxy = libexec/"bootstrap/runtime/browser_network_proxy.js"
    runtime_pkg = libexec/"bootstrap/runtime/package.json"
    runtime_lock = libexec/"bootstrap/runtime/package-lock.json"
    runtime_node_modules = libexec/"bootstrap/runtime/node_modules"
    (libexec/"stdlib").install Dir["#{stdlib}/*.heat"] if stdlib.exist?
    if bridge.exist?
      (libexec/"runtime").install bridge
      (libexec/"runtime").install network_proxy
      (libexec/"runtime").install runtime_pkg if runtime_pkg.exist?
      (libexec/"runtime").install runtime_lock if runtime_lock.exist?
      (libexec/"runtime").install runtime_node_modules if runtime_node_modules.exist?
    end

    (bin/"heatc").write <<~SH
      #!/bin/bash
      HEAT_HOME="#{libexec}"
      HEAT_REAL="$HEAT_HOME/bin/heatc.real"
      export HEAT_HOME
      USER_CWD="$PWD"
      args=()

      heat_abs_path_arg() {
        case "$1" in
          /*) printf '%s\\n' "$1" ;;
          *)  printf '%s\\n' "$USER_CWD/$1" ;;
        esac
      }

      if [ "${1:-}" = "mcp" ]; then
        args=("mcp")
        shift
        if [ "$#" -gt 0 ]; then
          sub="$1"
          args+=("$sub")
          shift
          case "$sub" in
            init)
              if [ "$#" -gt 0 ]; then args+=("$1"); shift; fi
              while [ "$#" -gt 0 ]; do args+=("$1"); shift; done ;;
            doctor-install)
              while [ "$#" -gt 0 ]; do args+=("$1"); shift; done ;;
            try-support-demo)
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  --out-dir)
                    args+=("$1"); shift
                    if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi ;;
                  *) args+=("$1"); shift ;;
                esac
              done ;;
            eval-summary)
              if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  --output)
                    args+=("$1"); shift
                    if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi ;;
                  *) args+=("$1"); shift ;;
                esac
              done ;;
            inspect-tool|install-codex|install-gemini|check|tools-list|call-dispatch|usage-manifest|usage-event-schema|context-budget|runtime-authority|runtime-ops|protocol-manifest|host-config|claude-desktop-config|gateway-launch|review-bundle|build|artifact-diff|validate|doctor|status|logs|diagnose|serve)
              if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi
              while [ "$#" -gt 0 ]; do args+=("$1"); shift; done ;;
            install-claude-desktop|install-gateway)
              if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  --config)
                    args+=("$1"); shift
                    if [ "$#" -gt 0 ]; then args+=("$(heat_abs_path_arg "$1")"); shift; fi ;;
                  *) args+=("$1"); shift ;;
                esac
              done ;;
            *)
              while [ "$#" -gt 0 ]; do args+=("$1"); shift; done ;;
          esac
        fi
      else
        for a in "$@"; do
          case "$a" in
            /*|-*|check|build|test|heal|version|help) args+=("$a") ;;
            *) args+=("$USER_CWD/$a") ;;
          esac
        done
      fi

      export PATH="$HEAT_HOME/bin:$PATH"
      cd "$HEAT_HOME" && exec "$HEAT_REAL" "${args[@]}"
    SH

    (bin/"heat-mcp").write <<~SH
      #!/bin/bash
      if [ "$#" -eq 0 ]; then
        exec "#{bin}/heatc" mcp help
      fi
      exec "#{bin}/heatc" mcp "$@"
    SH
    (bin/"heatcheck").write <<~SH
      #!/bin/bash
      exec "#{libexec}/bin/heatcheck" "$@"
    SH
    chmod 0755, bin/"heatc"
    chmod 0755, bin/"heat-mcp"
    chmod 0755, bin/"heatcheck"
  end

  test do
    assert_match "heatc", shell_output("#{bin}/heatc version")
    assert_match "heatc mcp", shell_output("#{bin}/heat-mcp help")
    assert_match "heatcheck", shell_output("#{bin}/heatcheck --version")
    (testpath/"stdlib_import.heat").write <<~EOS
      import flags
      fn main() -> Int [io]:
          let argv = ["prog", "--port=8080"]
          print(value: format("port {p}", p: parse_int_flag(args: argv, name: "--port", default: 3000)))
          return 0
    EOS
    system "#{bin}/heatc", "build", testpath/"stdlib_import.heat", "-o", testpath/"stdlib_import"
    assert_equal "port 8080", shell_output("#{testpath}/stdlib_import").strip

    (testpath/"browser_bridge_resolution.heat").write <<~EOS
      import browser

      fn main() -> Int [io]:
          match browser_launch(browser_kind: "chromium", headless: 1):
              Result.ok(_):
                  browser_close()
                  print(value: "browser bridge resolved")
                  return 0
              Result.error(message):
                  if message.contains(substring: "bridge_not_found:") == 1:
                      print(value: message)
                      return 1
                  if message.contains(substring: "playwright_not_installed:") == 1:
                      print(value: message)
                      return 1
                  print(value: "browser bridge resolved")
                  return 0
    EOS
    system "#{bin}/heatc", "build", testpath/"browser_bridge_resolution.heat",
           "-o", testpath/"browser_bridge_resolution"
    mkdir testpath/"no-home"
    out = shell_output(
      "HEAT_HOME= HOME=#{testpath}/no-home #{testpath}/browser_bridge_resolution",
    )
    assert_equal "browser bridge resolved", out.strip

    assert_match "MCP Builder install doctor ok", shell_output("PATH=#{bin}:$PATH #{bin}/heat-mcp doctor-install")
  end
end
