# Metric monitoring
#
# Compute some of the DORA metrics.

# export use token.nu
# export use http.nu
export use config.nu *
export use github.nu
export use jira.nu
export use source.nu

use duckdb.nu


# List all changesets.
export def "changeset list" [] {
    duckdb open data/changeset/*.parquet
    | update created_at { into datetime }
    | update updated_at { into datetime }
    | update closed_at { into datetime }
}

# List the changesets for the given date range and team members.
export def "changeset slice" [
    team: string@"team list names"
    --start_date (-s): datetime
    --end_date (-e): datetime
] {
    let team_handlers = team members $team
    | where start_date <= $start_date and end_date? == null or end_date? >= $end_date
    | get github_handle

    changeset list
    | where closed_at >= $start_date and closed_at <= $end_date
    | where creator in $team_handlers
}
