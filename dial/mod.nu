# Metric monitoring
#
# Compute some of the DORA metrics.

# export use token.nu
# export use http.nu
export use config.nu *
export use storage.nu
export use github.nu
export use jira.nu
export use source.nu

use duckdb.nu
use prelude.nu *

export def "changeset list" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let handles = team members $team | get github_handle | each { $"'($in)'" }
    let start_date = $start_date | into iso-timestamp
    let end_date = $end_date | into iso-timestamp
    let query = $"
        select
            id
            , repository
            , summary
            , creation_date
            , resolution_date
            , creator
        from
            changeset
        where
            creator in \(($handles | str join ",")\)
        and
            resolution_date between date '($start_date)' and date '($end_date)'
        order by resolution_date desc
    "

    storage query $query
    | update cells -c [creation_date resolution_date] { into datetime }
    | insert business_cycletime {|row| weekdays $row.creation_date $row.resolution_date }
    | insert total_cycletime {|row| $row.resolution_date - $row.creation_date }
}

# Computes the changeset cycletime for the given period and team.
export def "changeset cycletime" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let data = changeset list $start_date $end_date $team | get business_cycletime

    {
        avg: ($data | math avg)
        stddev: ($data | each { duration days } | math stddev | $in * 24 | into int | into duration -u hr)
        median: ($data | math median)
        max: ($data | math max)
        min: ($data | math min)
        size: ($data | length)
    }
}
