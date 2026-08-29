# Self-authored skills, promoted from oh-my-pi's `~/.omp/agent/managed-skills/`.
# Unlike the other two payloads there is no upstream input: the source is this
# repo's own `skills/` tree, copied verbatim — no sed normalisation, only gates.
{
  lib,
  runCommandLocal,
  src,
}:
let
  bannedEverywhere = [
    "git commit"
    "git push"
    "npx skills add"
    "npx skills init"
    "npx skills update"
    "(^|[^/])references/"
  ];

  bannedInSkillFiles = [
    "git add"
    "\\]\\(\\.\\./"
    "release-process"
  ];

  gate = include: patterns: ''
    for pattern in ${lib.escapeShellArgs patterns}; do
      if grep -rnE --include=${lib.escapeShellArg include} -- "$pattern" $out; then
        echo "managed-skills: banned pattern '$pattern' present in ${include} at the sites above" >&2
        exit 1
      fi
    done
  '';
in
runCommandLocal "managed-skills"
  {
    meta = {
      description = "Self-authored agent skills, gated for the same contract as the vendored payloads";
      platforms = lib.platforms.all;
    };
  }
  ''
    mkdir -p $out
    cp -r ${src}/. $out/
    chmod -R u+w $out

    ${gate "*.md" bannedEverywhere}
    ${gate "SKILL.md" bannedInSkillFiles}

    unresolved=0
    for target in $(grep -rhoE 'skill://[A-Za-z0-9_./-]+' --include='*.md' $out | sort -u); do
      [ -e "$out/''${target#skill://}" ] && continue
      echo "managed-skills: '$target' resolves to nothing:" >&2
      grep -rnF --include='*.md' -- "$target" $out >&2
      unresolved=1
    done
    [ "$unresolved" -eq 0 ]
  ''
