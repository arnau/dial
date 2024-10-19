use config.nu *
use prelude.nu *
use github.nu
use storage.nu

# Fetches changesets for a single team time-window (see `team time-window`).
export def "fetch-window" [] {
    let window: record = $in
    let orgs = $window.orgs
    let start_date = ($window.start_date | into iso-datestamp)
    let end_date = ($window.end_date | into iso-datestamp)

    let handles = ($window.members | get github_handle)
    let query = {
        org: $orgs
        author: $handles
        is: merged
        merged: $"($start_date)..($end_date)"
    }

    let res = github pull-request fetch $query

    # Soft abort if at least one request failed.
    # TODO: review fail path for 422
    if ($res | where status != 200 | is-not-empty) {
        return $res
    }

    $res
    | get data.items
    | github pull-request normalise
    | tee { if ($in | is-not-empty) { $in | storage save changeset } }
    | do {
          let items = $in

          {
              table: changeset
              count: ($items | length)
              start_date: $window.start_date
              end_date: $window.end_date
          }
      }
}

# Fetches merged GitHub Pull Request for the team organisations for the given date range.
export def "fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    team time-windows $start_date $end_date $team
    | each { fetch-window }
}

# Fetches the timelines for any changeset stored for the given date range.
export def "timeline fetch" [start_date: datetime, end_date: datetime] {
    let start_date = ($start_date | into iso-datestamp)
    let end_date = ($end_date | into iso-datestamp)

    let query = $"
        select
            *
        from
            changeset
        where
            resolution_date between date '($start_date)' and date '($end_date)'
    "

    storage query $query
    | each {|row|
          $row.timeline_url
          | github pull-request timeline fetch
          | insert data.changeset_id $row.id
          | insert data.repository $row.repository
          | github pull-request timeline normalise
          | tee { if ($in | is-not-empty) { $in | storage save changeset_event } }
          | do {
                let items = $in

                {
                    table: changeset_event
                    count: ($items | length)
                    start_date: $start_date
                    end_date: $end_date
                }
            }
      }
}

export def "list" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
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
export def "cycletime" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let data = list $start_date $end_date $team | get business_cycletime

    {
        avg: ($data | math avg)
        stddev: ($data | each { duration days } | math stddev | duration from days)
        median: ($data | math median)
        max: ($data | math max)
        min: ($data | math min)
        size: ($data | length)
    }
}