class Heat < Formula
  desc "AI-authored programming language and policy-checked MCP builder"
  homepage "https://github.com/nchantarotwong/heat-releases"
  version "0.8.7"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.7/heat-darwin-arm64.tar.gz"
      sha256 "5d41576a55fcece6833d4929642228cfd0d984b0bbeb9359262706c25647e1b6"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.7/heat-linux-arm64.tar.gz"
      sha256 "37254d1f4ed59317adb151bcd8591d3a5eea183ee4b1ec7f5c8e3c194c6e38c6"
    else
      url "https://github.com/nchantarotwong/heat-releases/releases/download/v0.8.7/heat-linux-x86_64.tar.gz"
      sha256 "df84c62f1d2ded5c46c117843c9728041fcabcd438e675b09e170295791d116d"
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
    assert_match "MCP Builder install doctor ok", shell_output("PATH=#{bin}:$PATH #{bin}/heat-mcp doctor-install")
  end
end
