# Managing data fetched from sources such as GitHub.
use config.nu *
use prelude.nu *
use metrics.nu
use jira.nu
use storage.nu


# Fetches tickets for a single team time-window (see `team time-window`).
export def "fetch-window" [] {
    let window: record = $in
    let start_date = ($window.start_date | into iso-datestamp)
    let end_date = ($window.end_date | into iso-datestamp)

    let emails = ($window.members | get email)

    let res = jira ticket fetch $window.start_date $window.end_date $emails

    if ($res | where status != 200 | is-not-empty) {
        return $res
    }
    
    $res
    | get data?
    | jira ticket normalise
    | tee { if ($in | is-not-empty) { $in | storage save ticket } }
    | do {
          let items = $in

          {
              table: ticket
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
          }
      }
}


# Fetch Jira tickets for the given date range and team members. The result is persisted in `ticket`.
#
# ```nu
# dial ticket fetch 2024-09-23 2024-09-27 red-onions
# ```
export def "fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    team time-windows $start_date $end_date $team
    | each { fetch-window }
}


export def "timeline fetch" [start_date: datetime, end_date: datetime] {
    let start_date = $start_date | format date "%F"
    let end_date = $end_date | format date "%F"

    let query = $"
        select
            *
        from
            ticket
        where
            resolution_date between date '($start_date)' and date '($end_date)'
    "

    storage query $query
    | par-each {|row|
          let res = jira changelog fetch $row.key

          if ($res | where status != 200 | is-empty) {
              $res
              | get data?
              | flatten
              | jira changelog flatten
          } else {
              fail $"Failed to fetch ($row.key)"
          }
      }
    | flatten
    | tee { if ($in | is-not-empty) { $in | storage save ticket_status } }
    | do {
          let items = $in

          {
              table: ticket_status
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
          }
      }
}

export def "list by-members" [start_date: datetime, end_date: datetime, members: list] {
    let members = $members | get email | each { $"'($in)'" }
    let start_date = $start_date | into iso-timestamp
    let end_date = $end_date | into iso-timestamp
    let query = $"
        select
            key
            , type
            , summary
            , parent
            , assignee
            , creation_date
            , resolution_date
            , priority
            , resolution
            , status
        from
            ticket
        where
            assignee in \(($members | str join ",")\)
        and
            resolution_date between date '($start_date)' and date '($end_date)'
        order by resolution_date desc
    "

    storage query $query
    | update cells -c [creation_date resolution_date] { into datetime }
    | insert business_cycletime {|row| weekdays $row.creation_date $row.resolution_date }
    | insert natural_cycletime {|row| $row.resolution_date - $row.creation_date }
}


# Lists tickets for the given time interval split by window.
export def "list by-window" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let members = team members $team
    let windows = team event members $team
        | team event to-window
        | team window crop $start_date $end_date

    $windows
    | insert tickets {|window|
          let members = $members | where id in $window.members

          list by-members $window.start_date $window.end_date $members
      }
}

# A flattened list of changesets.
export def "list" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    list by-window $start_date $end_date $team
    | get tickets
    | flatten
}

# Computes the changeset cycletime for the given period and team.
export def "cycletime" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let data = list $start_date $end_date $team | get business_cycletime

    {
        avg: ($data | metrics avg)
        stddev: ($data | each { duration days } | metrics stddev | duration from days)
        median: ($data | metrics median)
        max: ($data | metrics max)
        min: ($data | metrics min)
        size: ($data | length)
    }
}
