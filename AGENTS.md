# Agent instructions

## GitHub Actions

- Pin every action in `uses:` to a full commit SHA, with its version in a trailing comment:
  `uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. Local actions
  (`./.github/actions/...`) are the exception.
  - The repository requires it (`sha_pinning_required`): a workflow with a tag or branch reference
    fails before it runs.
  - Resolve a tag with `gh api repos/<owner>/<action>/commits/<tag> -q .sha`.
  - When updating an action, bump the SHA and the comment together.
