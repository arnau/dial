use std assert
use ../prelude.nu [weekdays, "date weekday"]

# Naive implementation.
def naive_weekdays [start_date: datetime, end_date: datetime] {
    mut current_date = $start_date
    mut weekdays = 0

    while $current_date <= $end_date {
        # Monday = 1, Friday = 5
        if ($current_date | date weekday | $in <= 5) {
            $weekdays += 1
        }

        $current_date = ($current_date + 1day)
    }

    $weekdays * 24 | into int | into duration -u hr
}


#[test]
def test_bad_input [] {
    assert error { weekdays 2024-10-02 2024-10-01 }
}

#[test]
def test_one_weekday [] {
    let expected = (weekdays 2024-10-01 2024-10-01)
    let actual = 1day
    assert equal $actual $expected
}

#[test]
def test_weekdays_only [] {
    let expected = (weekdays 2024-10-07 2024-10-11)
    let actual = 5day
    assert equal $actual $expected
}

#[test]
def test_one_weekendday [] {
    let expected = (weekdays 2024-10-05 2024-10-05)
    let actual = 0day
    assert equal $actual $expected
}

#[test]
def test_one_weekend [] {
    let expected = (weekdays 2024-10-05 2024-10-06)
    let actual = 0day
    assert equal $actual $expected
}

#[test]
def test_partial_with_weekend [] {
    let expected = (weekdays 2024-10-04 2024-10-07)
    let actual = 2day
    assert equal $actual $expected
}

#[test]
def test_full_month [] {
    let expected = (weekdays 2024-10-01 2024-10-31)
    let actual = (naive_weekdays 2024-10-01 2024-10-31)
    assert equal $actual $expected
}

#[test]
def test_full_year [] {
    let expected = (weekdays 2024-01-01 2024-12-31)
    let actual = (naive_weekdays 2024-01-01 2024-12-31)
    assert equal $actual $expected
}
