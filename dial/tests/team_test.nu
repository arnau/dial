use std assert
use ../config.nu *

const member_list = [
    {
        id: alice
        email: "alice@redonions.net"
        github_handle: alice-onion
        start_date: 2024-01-01
    }
    {
        id: bob
        email: "bob@redonions.net"
        github_handle: bob-onion
        start_date: 2024-01-01
    }
    {
        id: charly
        email: "charly@redonions.net"
        github_handle: charly-onion
        start_date: 2024-01-01
        end_date: 2024-04-11
    }
    {
        id: debra
        email: "debra@redonions.net"
        github_handle: debra-onion
        start_date: 2024-02-01
        end_date: 2024-09-23
    }
]


#[test]
def test_no_members [] {
    let expected = []
    let actual = team event member-list []
    assert equal $expected $actual
}


#[test]
def test_member_set [] {
    let expected = [
        { action: add, timestamp: 2024-01-01, member: alice }
        { action: add, timestamp: 2024-01-01, member: bob }
        { action: add, timestamp: 2024-01-01, member: charly }
        { action: add, timestamp: 2024-02-01, member: debra }
        { action: remove, timestamp: 2024-04-11, member: charly }
        { action: remove, timestamp: 2024-09-23, member: debra }
    ]

    let actual = team event member-list $member_list

    assert equal $expected $actual
}

#[test]
def test_event_to_window [] {
    let events = team event member-list $member_list
    let expected = [
        {
            start_date: 2024-01-01
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-04-10
            members: [alice bob charly debra]
        }
        {
            start_date: 2024-04-11
            end_date: 2024-09-22
            members: [alice bob debra]
        }
        {
            start_date: 2024-09-23
            end_date: null
            members: [alice bob]
        }
    ]

    let actual = $events | team event to-window

    assert equal $expected $actual
}

#[test]
def test_window_crop [] {
    let windows = [
        {
            start_date: 2024-01-01
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-04-10
            members: [alice bob charly debra]
        }
        {
            start_date: 2024-04-11
            end_date: 2024-09-22
            members: [alice bob debra]
        }
        {
            start_date: 2024-09-23
            end_date: null
            members: [alice bob]
        }
    ]
    let expected = [
        {
            start_date: 2024-01-30
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-04-10
            members: [alice bob charly debra]
        }
        {
            start_date: 2024-04-11
            end_date: 2024-08-31
            members: [alice bob debra]
        }
    ]

    let actual = $windows | team window crop 2024-01-30 2024-08-31

    assert equal $expected $actual
}

#[test]
def test_window_crop_unbound_end [] {
    let windows = [
        {
            start_date: 2024-01-01
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-09-22
            members: [alice bob debra]
        }
        {
            start_date: 2024-09-23
            end_date: null
            members: [alice bob]
        }
    ]
    let expected = [
        {
            start_date: 2024-01-30
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-09-22
            members: [alice bob debra]
        }
        {
            start_date: 2024-09-23
            end_date: 2024-10-01
            members: [alice bob]
        }
    ]

    let actual = $windows | team window crop 2024-01-30 2024-10-01

    assert equal $expected $actual
}

#[test]
def test_window_crop_unbound_start [] {
    let windows = [
        {
            start_date: 2024-01-01
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-09-22
            members: [alice bob debra]
        }
        {
            start_date: 2024-09-23
            end_date: null
            members: [alice bob]
        }
    ]
    let expected = [
        {
            start_date: 2024-01-01
            end_date: 2024-01-31
            members: [alice bob charly]
        }
        {
            start_date: 2024-02-01
            end_date: 2024-02-25
            members: [alice bob debra]
        }
    ]

    let actual = $windows | team window crop 2023-01-01 2024-02-25

    assert equal $expected $actual
}
