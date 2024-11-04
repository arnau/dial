# Metric monitoring
#
# Compute some of the DORA metrics.

export use config.nu *
export use storage.nu
export use changeset.nu
export use ticket.nu

use prelude.nu *
use metrics.nu


# Deployment frequency (DF): How often does your organization deploy code to production?
#   Sources: GitHub PR, Drone, GitHub Action.
# Lead time for changes (LTFC): How long does it take to go from code committed to code running in production?
#   Sources: Jira ticket cycletime, GitHub issue cycletime, GitHub PR cycletime
# Change failure rate (CFR): What percentage of changes to production result in degraded service and need remediation?
#   Sources: Pagerduty, incident.io, Jira ticket bug, GitHub PR
# Time to restore (TTR): How long does it generally take to restore service when a service incident or a defect that impacts users occurs?
#   Source: Pagerduty, incident.io


# Summarises the DORA metrics for the given period and team.
#
# NOTE: The number of team members is calculated as a constant for the given period.
# This means that for periods with team changes DORA metrics will not be accurate.
#
# Example
#
# ```nu
# dial summary 2024-10-01 2024-10-31 red_onions
# ````
export def summary [start_date: datetime, end_date: datetime, team: string@"team list names"] {
    let member_list = team members $team
    let ticket_list = ticket list $start_date $end_date $team
    let changeset_list = changeset list $start_date $end_date $team

    let member_count = $member_list | length
    let ticket_count = $ticket_list | length
    let changeset_count = $changeset_list | length

    let business_cycletime = $ticket_list | get business_cycletime | metrics avg
    let natural_cycletime = $ticket_list | get natural_cycletime | metrics avg

    let cycletime = $business_cycletime / $member_count
    let throughput = $ticket_count / $member_count
    let deployment_frequency = $changeset_count / $member_count
    let workdays_count = weekdays $start_date $end_date

    {
        start_date: $start_date
        end_date: $end_date
        business_days_count: $workdays_count
        natural_days_count: $workdays_count

        team: $team
        member_count: $member_count

        ticket_count: $ticket_count
        changeset_count: $changeset_count

        business_cycletime: $business_cycletime
        natural_cycletime: $business_cycletime

        team_cycletime: $cycletime
        team_throughput: $throughput
        team_deployment_frequency: $deployment_frequency
    }
}
