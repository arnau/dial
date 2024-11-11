use prelude.nu ["into iso-datestamp"]
use std assert

# The dial config. Expects a `data/config.nu` file to exist.
#
# See the `data/config.example.nu`
export def main [] {
    open data/config.nuon
}

export def "team list" [] {
    main | get teams
}

export def "team list names" [] {
    team list | get name
}

# The list of organisations for the given team.
export def "team orgs" [team: string@"team list names"] {
    team list
    | where name == $team
    | get 0?.orgs
    | default []
}

# The list of repos for the given team.
export def "team repos" [team: string@"team list names"] {
    team list
    | where name == $team
    | get 0?.repos
    | default []
}

# The list of members for the given team.
export def "team members" [team: string@"team list names"] {
    team list
    | where name == $team
    | get 0?.members
    | default []
}

# The list of Jira projects for the given team.
export def "team jira_projects" [team: string@"team list names"] {
    team list | where name == $team | get 0.jira_projects
}


# Prefer `team event members`
export def "team event member-list" [members: list] {
    $members
    | reduce --fold [] {|member, events|
          let new_events = [
              {action: add, timestamp: $member.start_date, member: $member.id}
              (if ($member.end_date? | is-not-empty) {
                  {action: remove, timestamp: $member.end_date?, member: $member.id}
              })
          ] | compact

          $events | append $new_events
      }
    | sort-by timestamp action member
}

# Lists the team member additions and removals.
export def "team event members" [team: string@"team list names"] {
    let members = team members $team

    team event member-list $members
}


def "make-window" [start_date: datetime, end_date?: datetime] {
    {
        start_date: $start_date
        end_date: $end_date
        members: $in
    }
}

# Consume an event into a window. Helper for `window handle-event`
def "handle-event" [window: record] {
    let event = $in
    let members = $window
        | match $event.action {
              add => {
                  $in.members | append $event.member | uniq | sort
              }
              remove => {
                  $in.members | where $it != $event.member
              }
          }

    $window
    | update members $members
}

# Consumes an event, extending or creating windows. Helper for `team event to-window`
def "window handle-event" [context: record<windows: list, current: record>] {
    let event = $in

    if ($event.timestamp == $context.current.start_date) {
        {
            windows: $context.windows
            current: ($event | handle-event $context.current)
        }
    } else {
        let end_date = $event.timestamp - 1day
        let previous = $context.current | update end_date $end_date
        let current = $context.current.members | make-window $event.timestamp

        {
            windows: ($context.windows | append $previous)
            current: ($event | handle-event $current)
        }
    }
}

# Add a member to the current window.
#[test]
def test_window_event_add [] {
    let event = {action: add, timestamp: 2024-01-01, member: alice}
    let context = {
        windows: []
        current: ([bob] | make-window 2024-01-01)
    }
    let expected = {
        windows: []
        current: ([alice bob] | make-window 2024-01-01)
    }
    let actual = $event | window handle-event $context

    assert equal $expected $actual
}

# Remove a member from the current window.
#[test]
def test_window_event_remove [] {
    let event = {action: remove, timestamp: 2024-01-01, member: bob}
    let context = {
        windows: []
        current: ([alice bob] | make-window 2024-01-01)
    }
    let expected = {
        windows: []
        current: ([alice] | make-window 2024-01-01)
    }
    let actual = $event | window handle-event $context

    assert equal $expected $actual
}

# Add a member to a new window.
#[test]
def test_window_event_add_new [] {
    let event = {action: add, timestamp: 2024-02-01, member: bob}
    let context = {
        windows: []
        current: ([alice] | make-window 2024-01-01)
    }
    let expected = {
        windows: [([alice] | make-window 2024-01-01 2024-01-31)]
        current: ([alice bob] | make-window 2024-02-01)
    }
    let actual = $event | window handle-event $context

    assert equal $expected $actual
}


# Remove a member. Create a new window.
#[test]
def test_window_event_remove_new [] {
    let event = {action: remove, timestamp: 2024-02-01, member: bob}
    let context = {
        windows: []
        current: ([alice bob] | make-window 2024-01-01)
    }
    let expected = {
        windows: [([alice bob] | make-window 2024-01-01 2024-01-31)]
        current: ([alice] | make-window 2024-02-01)
    }
    let actual = $event | window handle-event $context

    assert equal $expected $actual
}

# Tranform a list of member events to time windows.
#
# To generate events use `team event members` or `team event member-list`.
export def "team event to-window" []: [
    list<record<timestamp: datetime, action: string, member: string>>
    -> list<record<start_date: datetime, end_date?: datetime, members: list<string>>>
] {
    let events = $in | sort-by timestamp action member

    let context = $events
        | reduce --fold {windows: [], current: null} {|event, context|
              if ($context.current | is-empty) {
                  let current = [$event.member] | make-window $event.timestamp

                  {windows: $context.windows, current: $current}
              } else {
                  $event | window handle-event $context
              }
          }

    $context.windows
    | append $context.current
}

# Takes a list of windows and crops them within the provided interval.
export def "team window crop" [start_date: datetime, end_date: datetime] {
    let windows = $in

    $windows
    | each {|window|
        if ($window.start_date > $end_date) { return null }

        let start_date = [$window.start_date $start_date] | math max
        let end_date = [$window.end_date $end_date] | compact | math min

        {
            start_date: $start_date
            end_date: $end_date
            members: $window.members
        }
    }
}


# Groups the team members into time windows where these members wher part of the team.
# Windows are cropped by the given start and end time.
export def "team time-windows" [
    start_date: datetime           # The start date of the period to slice.
    end_date: datetime             # The end date of the period to slice.
    team: string@"team list names" # The team to slice in time windows.
] {
    let members = team members $team
    let events = team event members $team
    let orgs = team orgs $team

    $events
    | team event to-window
    | team window crop $start_date $end_date
    | update members { wrap id | join $members id }
    | insert orgs $orgs
}
