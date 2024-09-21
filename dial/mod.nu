# Metric monitoring
#
# Compute some of the DORA metrics.

# export use token.nu
# export use http.nu
export use config.nu *
export use github.nu
export use source.nu

use duckdb.nu

# REVIEW: Rename/alias modules
# module gh {
#     export use ./github.nu *    
# }

# export use gh


# List merged PRs for the given team and period
export def "merged" [
    team: string@"team list names"
    --start_date (-s): datetime
    --end_date (-e): datetime
] {
    let team_handlers = team members $team
    | where start_date <= $start_date and end_date? == null or end_date? >= $end_date
    | get github_handle

    duckdb open data/merged/*.parquet
    | update created_at { into datetime }
    | update updated_at { into datetime }
    | update closed_at { into datetime }
    | where closed_at >= $start_date and closed_at <= $end_date
    | where creator in $team_handlers
}

# List all merged PRs.
export def "merged all" [] {
    duckdb open data/merged/*.parquet
    | update created_at { into datetime }
    | update updated_at { into datetime }
    | update closed_at { into datetime }
}

