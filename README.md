# Dial

An attempt to monitor Jira, GitHub and similar sources from a DORA perspective.


## Setup

- Install nushell.
- Install the `duckdb` CLI.
- Store a GitHub token in `$env.GITHUB_TOKEN`. Optionally you can store a 1Password reference which will be resolved at request time.
- Copy `data/config.example.nuon` to `data/config.nuon`.
- Run `use dial` to get the tool into scope.


## Implementation considerations

The foundation is Nushell to get a baseline of interactive structured data.


## Testing

```nu
use dial/testing.nu
testing run-tests
```
