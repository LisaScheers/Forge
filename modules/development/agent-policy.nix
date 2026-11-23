# Lisa's coding agents run with full access: no sandbox and no approval
# prompts (her choice, 2026-11-23). This module sets that in each client's own
# format, keeps the one hard rule (agents never read credential files through
# Claude's Read tool), and checks that the rendered configuration still matches.
{
  config,
  inputs,
  lib,
  ...
}: let
  # Credentials an agent never needs to read through Claude's Read tool. Shell
  # commands are not restricted.
  secretReads = [
    "~/.ssh/id_*"
    "~/.config/sops/age/**"
    "~/.codex/auth.json"
    "~/.config/cli-proxy-api-plus/client-api-key"
    "//run/agenix/**"
    "//run/agenix.d/**"
  ];
  claudeDeny = map (path: "Read(${path})") secretReads;
  # What the live settings files must contain once activation has merged them.
  livePolicy = {
    codex = {
      sandbox_mode = "danger-full-access";
      approval_policy = "never";
    };
    claude.permissions = {
      defaultMode = "bypassPermissions";
      deny = claudeDeny;
    };
  };
  # Keys Nix declared in each settings file before its retirement manifest existed.
  retiredPaths = {
    codex = [
      ["model_providers" "nook"]
      # MCP approval prompts, removed with the switch to full access.
      ["mcp_servers" "clerk_mcp" "default_tools_approval_mode"]
      ["mcp_servers" "cognee" "tools"]
    ];
    claude = [["env" "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB"]];
    antigravity = [];
    zed = [];
  };
  # Every leaf key path Nix sets in a settings file, such as
  # ["mcp_servers" "cognee" "url"]; a nested key dropped from Nix is then retired
  # too, not left behind inside a table Nix still declares.
  declaredPaths = settings:
    lib.concatLists (lib.mapAttrsToList (
        key: value:
          if builtins.isAttrs value && value != {}
          then map (path: [key] ++ path) (declaredPaths value)
          else [[key]]
      )
      settings);
  # The leaf paths inside the MCP server tables Nix owns in Codex's config.
  ownedCodexServers = pkgs: settings: pkgs.writeText "codex-owned-servers.json" (builtins.toJSON (builtins.filter (path: builtins.head path == "mcp_servers") (declaredPaths settings)));
  retireCommand = pkgs: "${pkgs.python3.withPackages (ps: [ps.tomli-w])}/bin/python3 -I ${./agent-policy/retire_settings.py}";
  policyFile = pkgs: pkgs.writeText "agent-policy-live.json" (builtins.toJSON livePolicy);
  contextBaseline = pkgs:
    pkgs.writeShellApplication {
      name = "agent-context-baseline";
      text = ''exec ${pkgs.python3}/bin/python3 -I ${./agent-policy/context_baseline.py} "$@"'';
    };
  policyStatus = pkgs: codexSettings:
    pkgs.writeShellApplication {
      name = "agent-policy-status";
      text = ''exec ${pkgs.python3}/bin/python3 -I ${./agent-policy/policy_status.py} ${policyFile pkgs} "''${1:-$HOME}" ${ownedCodexServers pkgs codexSettings}'';
    };
in {
  home.lisa = {
    config,
    lib,
    pkgs,
    ...
  }: let
    home = config.home.homeDirectory;
    # Each mutable settings file, the keys Nix declares in it now, and its manifest.
    settingsFiles =
      [
        {
          name = "codex";
          path = "${home}/.codex/config.toml";
          declared = declaredPaths config.programs.codex.settings;
        }
        {
          name = "claude";
          path = "${home}/.claude/settings.json";
          declared = declaredPaths config.programs.claude-code.settings;
        }
      ]
      ++ lib.optional config.programs.antigravity-cli.enable {
        name = "antigravity";
        path = "${home}/.gemini/antigravity-cli/settings.json";
        declared = declaredPaths config.programs.antigravity-cli.settings;
      }
      # Zed's merge also keeps MCP servers Nix removed from context_servers.
      ++ lib.optional config.programs.zed-editor.enable {
        name = "zed";
        path = "${config.xdg.configHome}/zed/settings.json";
        declared = declaredPaths config.programs.zed-editor.userSettings;
      };
    retire = file: ''
      run ${retireCommand pkgs} ${file.path} ${config.xdg.stateHome}/forge-agent-policy/${file.name}-managed.json \
        ${pkgs.writeText "${file.name}-declared.json" (builtins.toJSON (lib.unique file.declared))} \
        ${pkgs.writeText "${file.name}-retired.json" (builtins.toJSON retiredPaths.${file.name})}
    '';
  in {
    # The merges never remove keys; retire the ones Nix stopped declaring. The
    # step keeps its old name, so earlier manifests and ordering still apply.
    home.activation.codexRetireSettings =
      lib.hm.dag.entryAfter ["codexMutableSettings" "claudeCodeSettings" "antigravitySettings" "zedSettingsActivation"]
      (lib.concatMapStrings retire settingsFiles);
    # Mutable settings can drift from Nix between activations; report it at
    # every switch, and on demand with `agent-policy-status`.
    home.packages = [(policyStatus pkgs config.programs.codex.settings) (contextBaseline pkgs)];
    home.activation.agentPolicyStatus = lib.hm.dag.entryAfter ["codexRetireSettings"] ''
      ${lib.getExe (policyStatus pkgs config.programs.codex.settings)} "$HOME" || warnEcho "Live agent settings differ from agent-policy.nix; see the lines above."
    '';
    programs.claude-code.settings = {
      # Declared lists replace saved ones, so the empty lists clear earlier
      # ask rules and hooks from the mutable settings file.
      permissions = {
        inherit (livePolicy.claude.permissions) defaultMode deny;
        ask = [];
      };
      skipDangerousModePermissionPrompt = true;
      hooks.PreToolUse = [];
    };
  };

  home.workstation.programs.zed-editor.userSettings.agent = {
    tool_permissions.default = "allow";
    sandbox_permissions.allow_unsandboxed = true;
  };

  home.lisa-vega.programs.antigravity-cli.settings = {
    allowNonWorkspaceAccess = true;
    permissions.ask = [];
  };

  perSystem = {
    pkgs,
    system,
    ...
  }: let
    homes = lib.genAttrs ["lisa@vega" "lisa@asterion" "lisa@nook"] (name: config.flake.homeConfigurations.${name}.config);
    workstations = ["lisa@vega" "lisa@asterion"];
    nookCodex = config.flake.nixosConfigurations.nook.config.systemd.services.codex.serviceConfig.ExecStart;
    expect = label: condition: lib.optional (!condition) label;
    homeFailures = name: let
      home = homes.${name};
      codex = home.programs.codex;
      claude = home.programs.claude-code;
      servers = codex.settings.mcp_servers;
      prefixed = map (failure: "${name}: ${failure}");
    in
      prefixed (lib.concatLists [
        (expect "Codex must run with full access and no approval prompts"
          (codex.settings.sandbox_mode == "danger-full-access" && codex.settings.approval_policy == "never"))
        (expect "Codex must have no approval rules or hooks" (codex.rules == {} && codex.hooks == {}))
        (expect "Codex MCP servers must be exactly clerk_mcp, cognee, nixos, rea and webmcp"
          (builtins.attrNames servers == ["clerk_mcp" "cognee" "nixos" "rea" "webmcp"]))
        (expect "Codex must keep every MCP server's tools out of the initial context and reach them through tool search"
          (builtins.all (server: (server.omit_tools_from or []) == ["direct"]) (builtins.attrValues servers)))
        (expect "Claude must always defer MCP tools to tool search" (claude.settings.env.ENABLE_TOOL_SEARCH == "true"))
        (expect "Telemetry must leave out prompts and responses"
          (claude.settings.env.OTEL_LOG_USER_PROMPTS
            == "0"
            && codex.settings.otel.log_user_prompt == false
            && codex.settings.otel.log_agent_responses == false
            && codex.settings.otel.metrics_exporter == "none"
            && codex.settings.otel.tool_result.max_bytes == 0
            && claude.settings.env.OTEL_LOG_TOOL_DETAILS == "0"
            && claude.settings.env.OTEL_LOG_TOOL_CONTENT == "0"))
        (expect "Codex telemetry must name its host"
          (builtins.elem codex.settings.otel.environment ["vega" "asterion" "nook"]))
        (expect "Telemetry must reach the collector's OTLP/HTTP routes in the encoding it accepts"
          (lib.hasSuffix "/v1/logs" codex.settings.otel.exporter.otlp-http.endpoint
            && codex.settings.otel.exporter.otlp-http.protocol == "binary"
            && claude.settings.env.OTEL_EXPORTER_OTLP_PROTOCOL == "http/protobuf"))
        (expect "No MCP tool may ask for approval"
          (builtins.all (server: !(server ? default_tools_approval_mode) && !(server ? tools)) (builtins.attrValues servers)))
        (expect "Every stdio MCP server must run from the Nix store, not a package runner such as npx or uvx"
          (builtins.all (server: (server.command or null) == null || lib.hasPrefix builtins.storeDir server.command)
            (builtins.attrValues servers ++ builtins.attrValues home.programs.mcp.servers)))
        (expect "Claude must start in bypass mode with no ask rules or hooks, and deny only credential reads"
          (claude.settings.permissions
            == {
              defaultMode = "bypassPermissions";
              deny = claudeDeny;
              ask = [];
            }
            && claude.settings.hooks.PreToolUse == []
            && claude.settings.skipDangerousModePermissionPrompt))
        (expect "Claude's own memory must stay off; Cognee holds memory" (claude.settings.autoMemoryEnabled == false))
        (expect "Claude must load Clerk, mcp-nixos, webmcp and Cognee, and attach REA on demand with Codex's REA server"
          (builtins.attrNames home.programs.mcp.servers
            == ["clerk_mcp" "nixos" "webmcp"]
            && claude.mcpServers ? cognee
            && (builtins.fromJSON (builtins.unsafeDiscardStringContext home.home.file.".claude/mcp-available/rea.json".text)).mcpServers.rea.command
            == builtins.unsafeDiscardStringContext servers.rea.command))
        (expect "Claude must not auto-start project MCP servers" (claude.settings.enableAllProjectMcpServers == false))
        (expect "Codex and Claude must read the same AGENTS.md" (codex.context == claude.context))
        (expect "Shell-wide gateway variables would reroute clients that sign in directly"
          (!(home.home.sessionVariables ? OPENAI_BASE_URL) && !(home.home.sessionVariables ? ANTHROPIC_BASE_URL)))
        (expect "Zed must allow every tool, unsandboxed"
          (!(builtins.elem name workstations)
            || home.programs.zed-editor.userSettings.agent.tool_permissions
            == {default = "allow";}
            && home.programs.zed-editor.userSettings.agent.sandbox_permissions.allow_unsandboxed))
      ]);
    vega = homes."lisa@vega".programs.antigravity-cli;

    # The skill and MCP tables in docs/agents.md, rendered from Vega's home.
    vegaHome = homes."lisa@vega";
    claudeServers = builtins.attrNames vegaHome.programs.mcp.servers ++ builtins.attrNames vegaHome.programs.claude-code.mcpServers;
    codexServers = vegaHome.programs.codex.settings.mcp_servers;
    zedServers = builtins.attrNames vegaHome.programs.zed-editor.userSettings.context_servers;
    antigravityServers = builtins.attrNames vegaHome.programs.antigravity-cli.mcpServers;
    claudeDefers = (vegaHome.programs.claude-code.settings.env.ENABLE_TOOL_SEARCH or "") == "true";
    claudeOnDemand = name: vegaHome.home.file ? ".claude/mcp-available/${name}.json";
    loading = present: deferred:
      if !present
      then "not installed"
      else if deferred
      then "tool search"
      else "loaded at start";
    serverRow = name: let
      codexServer = codexServers.${name} or {};
    in "| ${name} | ${
      if claudeOnDemand name
      then "on demand"
      else loading (builtins.elem name claudeServers) claudeDefers
    } | ${loading (codexServers ? ${name}) (builtins.elem "direct" (codexServer.omit_tools_from or []))} | ${loading (builtins.elem name zedServers) false} | ${loading (builtins.elem name antigravityServers) false} |";
    skillCount = client: toString (builtins.length (builtins.attrNames vegaHome.programs.${client}.skills));
    pstackCount = toString (builtins.length (builtins.attrNames (builtins.readDir ./ai-skills/pstack/skills)));
    catalogue = lib.concatStringsSep "\n" ([
        "<!-- catalogue:start: rendered from Nix; checks.agent-policy prints the current version when this differs -->"
        "| Skills on Vega | Claude | Codex | Antigravity | Copilot |"
        "| --- | ---: | ---: | ---: | ---: |"
        "| Installed | ${skillCount "claude-code"} | ${skillCount "codex"} | ${skillCount "antigravity-cli"} | ${skillCount "github-copilot-cli"} |"
        "| Of which pstack, manual only | ${pstackCount} | ${pstackCount} | 0 | 0 |"
        ""
        "| MCP server | Claude | Codex | Zed | Antigravity |"
        "| --- | --- | --- | --- | --- |"
      ]
      ++ map serverRow (lib.unique (lib.sort builtins.lessThan (claudeServers ++ builtins.attrNames codexServers)))
      ++ ["<!-- catalogue:end -->"]);
    catalogueCurrent = lib.hasInfix catalogue (builtins.readFile ../../docs/agents.md);

    # docs/skills.md: every skill on Vega, its set, its clients and its summary.
    skillClients = {
      Claude = "claude-code";
      Codex = "codex";
      Antigravity = "antigravity-cli";
      Copilot = "github-copilot-cli";
    };
    installedSkills = client: builtins.attrNames vegaHome.programs.${client}.skills;
    tstackNames = ["council" "full-send" "full-stop" "sol-loop"];
    skillEntry = name: let
      bundled = ./ai-skills/skills + "/${name}";
      pstack = ./ai-skills/pstack/skills + "/${name}";
      isTstack = builtins.elem name tstackNames;
      extra = local.forge.ai-skills.extraSkills;
    in {
      inherit name;
      clients = builtins.filter (client: builtins.elem name (installedSkills skillClients.${client})) (builtins.attrNames skillClients);
      source =
        if builtins.pathExists bundled
        then "bundled"
        else if builtins.pathExists pstack
        then "pstack"
        else if isTstack
        then "tstack"
        else if extra ? ${name}
        then "pinned extra"
        else "REA";
      # This system's own copy of tstack, so nothing is built for Vega here.
      dir =
        if builtins.pathExists bundled
        then bundled
        else if builtins.pathExists pstack
        then pstack
        else if isTstack
        then local.programs.codex.skills.${name}
        else extra.${name} or null;
    };
    skillNames = lib.unique (lib.concatMap installedSkills (builtins.attrValues skillClients));
    catalogueTools = pkgs.python3.withPackages (ps: [ps.pyyaml]);
    skillsCatalogue = pkgs.runCommand "skills.md" {nativeBuildInputs = [catalogueTools];} ''
      python3 -B ${./agent-policy/skills_catalogue.py} render ${pkgs.writeText "skills.json" (builtins.toJSON (map skillEntry skillNames))} ${./ai-skills/AGENTS.md} > "$out"
    '';
    # Each skill name must come from exactly one set; a second copy would
    # silently replace the first in whichever client merges them last.
    skillSets = {
      bundled = builtins.attrNames (builtins.readDir ./ai-skills/skills);
      pstack = builtins.attrNames (builtins.readDir ./ai-skills/pstack/skills);
      tstack = tstackNames;
      extra = builtins.attrNames local.forge.ai-skills.extraSkills;
      rea = ["reverse-engineer-anything"];
    };
    allSetNames = lib.concatLists (builtins.attrValues skillSets);
    duplicateSkills = lib.unique (builtins.filter (name: builtins.length (builtins.filter (other: other == name) allSetNames) > 1) allSetNames);

    # T3 Code and Zed on Vega: the drivers and models Lisa uses.
    t3 = vegaHome.programs.t3code.userSettings;
    clientContracts =
      expect "T3 must enable its Codex, Claude and Antigravity drivers, with Codex on its own provider and Claude from the profile"
      (t3.providerInstances.codex.enabled
        && t3.providerInstances.codex.config.launchArgs == "-c model_provider=\"openai\""
        && t3.providerInstances.claudeAgent.enabled
        && t3.providerInstances.claudeAgent.config.binaryPath == "${vegaHome.home.profileDirectory}/bin/claude"
        && t3.providerInstances.antigravity.enabled
        && t3.defaultModelSelection.instanceId == "codex")
      ++ expect "Zed's agent must use the Codex subscription"
      (vegaHome.programs.zed-editor.userSettings.agent.default_model.provider == "codex");

    # The exported module, in a home that has nothing else of Lisa's.
    standalone =
      (inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          config.flake.modules.homeManager.ai-environment
          {
            home = {
              username = "ai-environment-test";
              homeDirectory =
                if pkgs.stdenv.hostPlatform.isDarwin
                then "/Users/ai-environment-test"
                else "/home/ai-environment-test";
              stateVersion = "26.11";
            };
            programs.codex = {
              enable = true;
              package = null;
            };
            programs.claude-code = {
              enable = true;
              package = null;
            };
          }
        ];
      }).config;
    standaloneWorks =
      standalone.programs.codex.context
      == ./ai-skills/AGENTS.md
      && standalone.programs.claude-code.skills ? file-pr
      && standalone.programs.codex.skills ? principle-fix-root-causes;

    # Snapshots of each home's rendered agent settings, kept in tests/agent-config.
    # Store paths become `<store>`, so a Nixpkgs update alone changes nothing.
    normalise = value:
      if builtins.isAttrs value
      then builtins.mapAttrs (_: normalise) value
      else if builtins.isList value
      then map normalise value
      else if builtins.isString value
      then
        builtins.unsafeDiscardStringContext (lib.concatMapStrings (part:
          if builtins.isList part
          then "<store>"
          else part) (builtins.split "/nix/store/[a-z0-9]{32}-[^/\"' ]*" value))
      else if builtins.isPath value
      then "<path:${baseNameOf value}>"
      else value;
    renderedConfig = name: let
      home = homes.${name};
      workstation = builtins.elem name workstations;
    in
      normalise ({
          codex = home.programs.codex.settings;
          claude = home.programs.claude-code.settings // {inherit (home.programs.claude-code) mcpServers lspServers;};
          mcp = home.programs.mcp.servers;
        }
        // lib.optionalAttrs workstation {zed.agent = home.programs.zed-editor.userSettings.agent // {inherit (home.programs.zed-editor.userSettings) context_servers;};}
        // lib.optionalAttrs (name == "lisa@vega") {
          antigravity = home.programs.antigravity-cli.settings // {inherit (home.programs.antigravity-cli) mcpServers;};
          t3.providerInstances = home.programs.t3code.userSettings.providerInstances;
        });
    snapshotFile = name: ../../tests/agent-config + "/${name}.json";
    staleSnapshots = builtins.filter (name:
      !(builtins.pathExists (snapshotFile name))
      || builtins.fromJSON (builtins.readFile (snapshotFile name)) != builtins.fromJSON (builtins.toJSON (renderedConfig name)))
    (builtins.attrNames homes);
    snapshots = pkgs.runCommand "agent-config-snapshots" {nativeBuildInputs = [pkgs.python3];} ''
      mkdir "$out"
      ${lib.concatMapStrings (name: ''
        python3 -c 'import json, sys; print(json.dumps(json.load(open(sys.argv[1])), indent=2, sort_keys=True))' \
          ${pkgs.writeText "${name}.json" (builtins.toJSON (renderedConfig name))} > "$out/${name}.json"
      '') (builtins.attrNames homes)}
    '';

    agentSkillNames = pkgs.writeText "agent-skill-names.json" (builtins.toJSON (lib.unique (installedSkills "claude-code" ++ installedSkills "codex")));
    failures =
      lib.concatMap homeFailures (builtins.attrNames homes)
      ++ clientContracts
      ++ expect "Zed and Antigravity, which load every schema up front, must get only nixos and webmcp"
      (zedServers == ["nixos" "webmcp"] && antigravityServers == ["nixos" "webmcp"])
      ++ expect "Skill names must be unique across sets; duplicated: ${toString duplicateSkills}" (duplicateSkills == [])
      ++ expect "modules.homeManager.ai-environment must work on its own" standaloneWorks
      ++ expect "lisa@vega: Antigravity must read AGENTS.md and run without workspace limits or ask rules"
      (vega.context.GEMINI
        == homes."lisa@vega".programs.codex.context
        && vega.settings.allowNonWorkspaceAccess
        && vega.settings.permissions.ask == [])
      ++ expect "nook: nginx must route OTLP logs, metrics and traces to the collector"
      (config.flake.nixosConfigurations.nook.config.services.nginx.virtualHosts."otel.local.bylisa.dev".locations ? "~ ^/v1/(logs|metrics|traces)$")
      # Every client loads the shared instructions in full, in every session.
      ++ expect "AGENTS.md must stay under 16 KiB"
      (builtins.stringLength (builtins.readFile ./ai-skills/AGENTS.md) <= 16384)
      ++ expect "nook: the Codex service must use the shared Cognee server"
      (lib.hasInfix "mcp_servers.cognee.url=" nookCodex);
    # The home this system builds, so its generated files exist here.
    local =
      homes.${
        {
          aarch64-darwin = "lisa@vega";
          aarch64-linux = "lisa@asterion";
          x86_64-linux = "lisa@nook";
        }.${
          system
        }
      };
    # Home Manager's own merge steps, which write the live files at activation.
    zedMerges = local.home.activation ? zedSettingsActivation;
    merge = pkgs.writeText "agent-settings-merge.sh" (lib.concatMapStringsSep "\n" (step: local.home.activation.${step}.data) (
      ["codexMutableSettings" "claudeCodeSettings"]
      ++ lib.optional zedMerges "zedSettingsActivation"
      ++ ["codexRetireSettings"]
    ));
  in {
    packages.agent-skills-catalogue = skillsCatalogue;
    packages.agent-config-snapshots = snapshots;
    checks.agent-policy = assert lib.assertMsg (failures == []) "Agent configuration no longer matches agent-policy.nix:\n${lib.concatStringsSep "\n" failures}";
    assert lib.assertMsg (staleSnapshots == []) "Rendered agent settings changed for ${toString staleSnapshots}; review the change, then: nix build .#agent-config-snapshots && cp result/*.json tests/agent-config/";
    assert lib.assertMsg catalogueCurrent "docs/agents.md's catalogue differs from Nix; replace it with:\n${catalogue}";
      pkgs.runCommand "agent-policy" {
        nativeBuildInputs = [(pkgs.python3.withPackages (ps: [ps.pyyaml ps.tomli-w])) pkgs.gnused];
      } ''
        cd ${./agent-policy}
        python3 -B -m unittest test_policy_status test_retire_settings test_context_baseline test_skills_catalogue
        python3 -B check_skills.py ${./ai-skills/skills} ${./ai-skills/pstack/skills}
        python3 -B skills_catalogue.py references ${./ai-skills/AGENTS.md} ${agentSkillNames}
        # `@` completion ranks the fuzzy match first and includes untracked files.
        project="$TMPDIR/project"
        mkdir -p "$project/src/components" "$project/.git"
        touch "$project/src/components/Button.tsx" "$project/src/main.py" "$project/notes.md" "$project/.git/HEAD"
        first=$(echo '{"query": "comp butt"}' | CLAUDE_PROJECT_DIR="$project" ${local.programs.claude-code.settings.fileSuggestion.command} | head -n 1)
        [ "$first" = src/components/Button.tsx ] || { echo "file suggestion returned '$first'" >&2; exit 1; }
        [ "$(echo '{"query": ""}' | CLAUDE_PROJECT_DIR="$project" ${local.programs.claude-code.settings.fileSuggestion.command} | grep -c .git/)" = 0 ]
        # The status line shows what Claude reports and skips what it leaves out.
        line=$(echo '{"model": {"display_name": "Opus 5.5"}, "effort": {"level": "high"}, "context_window": {"used_percentage": 23.4}, "rate_limits": {"five_hour": {"used_percentage": 41}}}' \
          | ${local.programs.claude-code.settings.statusLine.command})
        [ "$line" = "Opus 5.5 high · context 23% · 5h 41%" ] || { echo "status line printed '$line'" >&2; exit 1; }
        [ "$(echo '{"model": {"display_name": "Opus 5.5"}, "context_window": {"used_percentage": null}}' | ${local.programs.claude-code.settings.statusLine.command})" = "Opus 5.5" ]

        # The exported module writes the shared instructions for Codex on its own.
        cmp ${standalone.home.file.".codex/AGENTS.md".source} ${./ai-skills/AGENTS.md}
        if ! diff -u ${../../docs/skills.md} ${skillsCatalogue}; then
          echo "docs/skills.md is out of date: nix build .#agent-skills-catalogue && cp result docs/skills.md" >&2
          exit 1
        fi

        # A home left from the earlier approval policy: a sandbox, ask rules,
        # a hook, an npx server and the retired gateway provider.
        home="$TMPDIR/home"
        mkdir -p "$home/.codex" "$home/.claude"
        printf '%s\n' 'approval_policy = "on-request"' 'sandbox_mode = "workspace-write"' 'app_owned = "kept"' \
          '[mcp_servers.webmcp]' 'command = "npx"' '[mcp_servers.node_repl]' 'command = "node"' \
          '[model_providers.nook]' 'base_url = "https://gateway"' \
          '[mcp_servers.clerk_mcp]' 'default_tools_approval_mode = "prompt"' \
          '[mcp_servers.cognee.tools.forget]' 'approval_mode = "prompt"' > "$home/.codex/config.toml"
        echo '{"theme": "dark", "permissions": {"ask": ["Bash(just deploy:*)"]}, "hooks": {"PreToolUse": [{"matcher": "Bash"}]}, "env": {"CLAUDE_CODE_SUBPROCESS_ENV_SCRUB": "1"}}' \
          > "$home/.claude/settings.json"
        ${lib.optionalString zedMerges ''
          # Zed: a server Nix declared at the last activation and has since removed.
          mkdir -p "$home/.config/zed" "$home/.local/state/forge-agent-policy"
          echo '{"app_owned": "kept", "context_servers": {"retired": {"command": "old"}}}' > "$home/.config/zed/settings.json"
          echo '[["context_servers", "retired", "command"]]' > "$home/.local/state/forge-agent-policy/zed-managed.json"
        ''}        ! python3 -B policy_status.py ${policyFile pkgs} "$home" ${ownedCodexServers pkgs local.programs.codex.settings} 2>/dev/null
        # Run the real merge against it, then require the policy and the kept keys.
        sed "s#${local.home.homeDirectory}#$home#g" ${merge} > "$TMPDIR/merge.sh"
        bash -c 'errorEcho() { echo "$@" >&2; }; run() { "$@"; }; set -eu; source "$1"' merge "$TMPDIR/merge.sh"
        python3 -B policy_status.py ${policyFile pkgs} "$home" ${ownedCodexServers pkgs local.programs.codex.settings}
        python3 -B - "$home" <<'PY'
        import json, pathlib, sys, tomllib
        home = pathlib.Path(sys.argv[1])
        codex = tomllib.loads((home / ".codex/config.toml").read_text())
        claude = json.loads((home / ".claude/settings.json").read_text())
        assert codex["app_owned"] == "kept" and claude["theme"] == "dark", "the merge dropped a key the app owns"
        assert codex["mcp_servers"]["node_repl"]["command"] == "node", "an app-owned server was retired"
        assert "model_providers" not in codex, "a retired gateway provider survived"
        assert "default_tools_approval_mode" not in codex["mcp_servers"]["clerk_mcp"], "a retired nested key survived"
        assert "tools" not in codex["mcp_servers"]["cognee"], "a retired nested table survived"
        assert "npx" not in codex["mcp_servers"]["webmcp"]["command"]
        assert codex["mcp_servers"]["rea"]["omit_tools_from"] == ["direct"]
        assert codex["otel"]["log_user_prompt"] is False
        assert claude["permissions"]["ask"] == [] and claude["hooks"]["PreToolUse"] == [], "old ask rules or hooks survived"
        assert "CLAUDE_CODE_SUBPROCESS_ENV_SCRUB" not in claude["env"], "a retired Claude setting survived"
        assert claude["autoMemoryEnabled"] is False and claude["env"]["ENABLE_TOOL_SEARCH"] == "true"
        zed_path = home / ".config/zed/settings.json"
        if zed_path.exists():
            zed = json.loads(zed_path.read_text())
            assert zed["app_owned"] == "kept", "the Zed merge dropped a key it does not own"
            assert sorted(zed["context_servers"]) == ["nixos", "webmcp"], "a removed Zed server survived"
        PY
        touch "$out"
      '';
  };
}
