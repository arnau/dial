# Managing data fetched from sources such as GitHub.
use config.nu *
use github.nu
use jira.nu
use duckdb.nu
use storage.nu

const allowlist_events = [
    assigned        
    closed
    commented
    committed
    convert_to_draft
    merged
    ready_for_review
    renamed
    reopened
    review_dismissed
    review_requested
    review_request_removed
    reviewed
    unassigned
]

# Fetches merged GitHub Pull Request for the team organisations for the given date
# range. The result is persisted in `changeset`.
export def "changeset fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let orgs = team orgs $team
    let start_date = ($start_date | format date "%F")
    let end_date = ($end_date | format date "%F")

    let res = github pr list merged -s $start_date {org: $orgs}

    # Soft abort if at least one request failed.
    # TODO: review fail path
    if ($res | where status != 200 | is-not-empty) {
        return $res
    }

    $res
    | get data.items
    | github pr list normalise
    | tee {
          if ($in | is-not-empty) { $in | storage save changeset }
      }
    | do {
          let items = $in

          {
              table: changeset
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
          }
      }
}

# Fetches the timelines for any changeset stored for the given date range.
# The result is persisted in `changeset_timeline`.
export def "changeset timeline fetch" [start_date: datetime, end_date: datetime] {
    let start_date = $start_date | format date "%F"
    let end_date = $end_date | format date "%F"

    storage query $"select * from changeset where resolution_date >= date '($start_date)' and resolution_date <= date '($end_date)'"
    | par-each {|row|
          $row.timeline_url
          | github pr timeline-url
          | get data
          | flatten
          | reject id?
          | insert changeset_id $row.id
          | insert repository $row.repository
          | upsert source github
      }
    | flatten
    | collect
    | where { $in.event in $allowlist_events }
    | upsert actor {|row|
          match $row.event {
              committed => $row.author.email
              commented | reviewed => $row.user.login
              _ => $row.actor.login
          }
      }
    | insert timestamp {|row|
          match $row.event {
              committed => $row.author.date
              reviewed => $row.submitted_at
              _ => $row.created_at
          }
      }
    | rename --column {node_id: id}
    | select id changeset_id repository timestamp event actor url? source
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


# Fetch Jira tickets for the given date range and team members. The result is persisted in `ticket`.
#
# ```nu
# dial ticket fetch 2024-09-23 2024-09-27 red-onions
# ```
export def "ticket fetch" [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let emails = team members $team | get email

    let res = jira ticket fetch $start_date $end_date $emails

    $res
    | where status == 200
    | get data?
    | flatten
    | jira ticket flatten
    | tee { if ($in | is-not-empty) { $in | storage save ticket } }
    | do {
          let items = $in

          {
              table: ticket
              count: ($items | length)
              start_date: $start_date
              end_date: $end_date
              errors: ($res | where status != 200)
          }
      }
}


export def "ticket timeline fetch" [start_date: datetime, end_date: datetime] {
    let start_date = $start_date | format date "%F"
    let end_date = $end_date | format date "%F"

    storage query $"select * from ticket where resolution_date >= date '($start_date)' and resolution_date <= date '($end_date)'"
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
