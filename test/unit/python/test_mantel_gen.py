import sys

import pytest
from mantel_gen import default_input, verbose_input, main

GROUPS = ["isoenergy", "mantel", "qe", "wfc2bin", "yambo"]


def parse_template(text):
    """{group: {key: value}} for a mantel.in template, ignoring comments."""
    groups = {}
    current = None
    for line in text.splitlines():
        line = line.split("!")[0].strip()
        if line.startswith("&"):
            current = line[1:]
            groups[current] = {}
        elif line == "/":
            current = None
        elif "=" in line and current is not None:
            key, value = line.split("=", 1)
            groups[current][key.strip()] = value.strip()
    return groups


@pytest.mark.parametrize("contents", [default_input(), verbose_input()])
def test_every_group_is_present_and_closed(contents):
    lines = [line.strip() for line in contents.splitlines()]

    assert sorted(parse_template(contents)) == GROUPS
    assert len([l for l in lines if l.startswith("&")]) == 5
    assert len([l for l in lines if l == "/"]) == 5


def test_header_is_a_comment():
    assert default_input().startswith("! mantel.in file generated on")
    assert verbose_input().startswith("! mantel.in file generated on")


def test_verbose_matches_default_apart_from_comments():
    assert parse_template(verbose_input()) == parse_template(default_input())


def test_group_keys():
    template = parse_template(default_input())

    assert template["qe"].keys() == {"qe_kgrid", "nbnd", "wfc_dir", "scf_in"}
    assert template["yambo"].keys() == {"yambo_kgrid", "chi_bands", "NGsBlkXs", "yambo_dir"}
    assert template["wfc2bin"].keys() == {"Gmax"}
    assert template["isoenergy"].keys() == {"numE", "minE", "maxE", "sigma"}


def test_isoenergy_defaults():
    assert parse_template(default_input())["isoenergy"] == {
        "numE": "200",
        "minE": "-20.0",
        "maxE": "20.0",
        "sigma": "0.2",
    }


def test_mantel_defaults():
    mantel = parse_template(default_input())["mantel"]

    assert mantel["iq_min"] == "1"
    assert mantel["iq_max"] == "-1"
    assert mantel["qtf_method"] == '"fit"'
    assert mantel["qtf_fit_nq"] == "3"


def test_paths_are_quoted():
    template = parse_template(default_input())

    assert template["qe"]["wfc_dir"] == '"./WFC"'
    assert template["qe"]["scf_in"] == '"scf.in"'
    assert template["yambo"]["yambo_dir"] == '"./YAMBO"'


def test_verbose_comments_every_key():
    lines = verbose_input().splitlines()

    for i, line in enumerate(lines):
        stripped = line.split("!")[0].strip()
        if "=" not in stripped:
            continue
        previous = [l.strip() for l in lines[:i] if l.strip()][-1]
        assert previous.startswith("!"), f"{stripped} has no comment above it"


