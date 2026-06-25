class Heat < Formula
  desc "AI-authored programming language and policy-checked MCP builder"
  homepage "https://github.com/nchantarotwong/heat-releases"
  version "0.8.1"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.1/heat-darwin-arm64.tar.gz"
      sha256 "55e0b18b972a6f4773067c358a1351b426eab20bac39cf8788388dde90916625"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.1/heat-linux-arm64.tar.gz"
      sha256 "b7a012b7641cae1d364a9f7daaafb7fb1a7ac4ad4d71c949c4f9d1d339995309"
    else
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.1/heat-linux-x86_64.tar.gz"
      sha256 "90fb80604d25c2f0e16c4ead50a2dbf2494c743de63639a7cddea6cb1b4d7ae9"
    end
  end

  def install
    libexec.install Dir["*"]
    stdlib = libexec/"bootstrap/stdlib"
    bridge = libexec/"bootstrap/runtime/playwright_bridge.js"
    (libexec/"stdlib").install Dir["#{stdlib}/*.heat"] if stdlib.exist?
    (libexec/"runtime").install bridge if bridge.exist?

    (bin/"heatc").write <<~SH
      #!/bin/bash
      HEAT_HOME="#{libexec}"
      HEAT_REAL="$HEAT_HOME/bin/heatc.real"
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
    assert_match "MCP Builder install doctor ok", shell_output("PATH=#{bin}:$PATH #{bin}/heat-mcp doctor-install")
  end
end
