# Dial

An attempt to monitor Jira, GitHub and similar sources from a DORA perspective.


## Setup

- Install nushell.
- Install the `duckdb` CLI.
- Copy `data/config.example.nuon` to `data/config.nuon`.
- Run `use dial` to get the tool into scope.

### Environment variables

Fetching from all sources require a fair amount of environment variables:

- `GITHUB_TOKEN`. A GitHub token with access to read repositories in your organisation.
- `JIRA_TOKEN`. A Jira Cloud token for your organisation's instance.
- `JIRA_USERNAME`. Your Jira Cloud username, i.e. your Atlassian's email.
- `JIRA_BASEURL`. The Jira Cloud base URL for your organisation's instance. E.g. `https://myorganisation.atlassian.net`

If you use a secrets manager it can be slow to decrypt all of them. The following example shows one way of handling it for secrets stored in 1Password:

```nu
# .dial.nu
use dial/token.nu

{
    GITHUB_TOKEN: (token read $env.GITHUB_TOKEN_OP)
    JIRA_TOKEN: (token read $env.JIRA_TOKEN_OP)
    JIRA_USERNAME: (token read $env.JIRA_USERNAME_OP)
    JIRA_BASEURL: (token read $env.JIRA_BASEURL_OP)
}
| load-env
```

You can do the following to decrypt all values scoped for the given session:

```nu
# interactive nushell session
> source .env.nu
```

Or leverage the env var hooks to automatically load/unload them:

```nu
$env.config.hooks.env_change.PWD = [
    {
        condition: {|| (".dial.nu" | path exists) }
        code: "source .dial.nu"
    }
    {
        condition: {|| not (".dial.nu" | path exists) }
        code: "hide-env DIAL_CONTEXT GITHUB_TOKEN JIRA_TOKEN JIRA_USERNAME JIRA_BASEURL"
    }
]
```


## Implementation considerations

The foundation is Nushell to get a baseline of interactive structured data.


## Testing

```nu
use dial/testing.nu
testing run-tests
```
