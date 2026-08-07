"""Structural tests for the detection rules.

These run anywhere, with no Elasticsearch. They catch the mistakes that make a
rule silently useless: a typo in a field name that no index maps, a threshold
rule with no aggregation, a rule nobody documented, fixtures that do not
actually exercise the rule.

The tests that prove a rule *matches what it claims to match* need a real
Elasticsearch and live in test_rules_against_elasticsearch.py.
"""

from __future__ import annotations

from typing import Any

import pytest
from conftest import (
    DETECTIONS_DOC,
    VALID_SEVERITIES,
    VALID_TYPES,
    audit_index_mapping,
    load_rules,
)

REQUIRED_KEYS = {
    "id",
    "name",
    "severity",
    "enabled",
    "type",
    "index",
    "interval",
    "lookback",
    "description",
    "rationale",
    "mitre",
    "false_positives",
    "response",
    "query",
    "fixtures",
}


def test_at_least_four_rules_exist() -> None:
    assert len(load_rules()) >= 4


def test_rule_ids_are_unique() -> None:
    ids = [r["id"] for r in load_rules()]
    assert len(ids) == len(set(ids))


def test_rule_id_matches_filename(rule: dict[str, Any]) -> None:
    assert rule["_path"].stem == rule["id"]


def test_required_keys_present(rule: dict[str, Any]) -> None:
    missing = REQUIRED_KEYS - set(rule)
    assert not missing, f"{rule['id']} is missing {sorted(missing)}"


def test_severity_and_type_are_valid(rule: dict[str, Any]) -> None:
    assert rule["severity"] in VALID_SEVERITIES
    assert rule["type"] in VALID_TYPES


def test_rationale_is_substantive(rule: dict[str, Any]) -> None:
    """A rule without a written explanation of what it catches is not finished.

    The bar is deliberately low as a number and high as an intent: enough words
    that someone woken at 03:00 by this rule learns something from it.
    """
    assert len(rule["rationale"].split()) >= 40, f"{rule['id']}: rationale too thin"
    assert rule["false_positives"], f"{rule['id']}: no false positives listed"
    assert rule["response"], f"{rule['id']}: no response guidance"


def test_mitre_mapping_is_well_formed(rule: dict[str, Any]) -> None:
    assert rule["mitre"], f"{rule['id']} has no MITRE mapping"
    for entry in rule["mitre"]:
        assert set(entry) == {"tactic", "tactic_id", "technique", "technique_id"}
        assert entry["tactic_id"].startswith("TA")
        assert entry["technique_id"].startswith("T")


def test_threshold_rules_declare_a_threshold_and_aggregation(
    rule: dict[str, Any],
) -> None:
    if rule["type"] != "threshold":
        assert "threshold" not in rule, f"{rule['id']} is a query rule with a threshold"
        return

    threshold = rule["threshold"]
    assert threshold["value"] > 0
    agg = rule["aggregation"]["terms"]
    assert agg["field"] == threshold["field"], (
        f"{rule['id']}: aggregation groups by {agg['field']} but the threshold "
        f"is declared on {threshold['field']}"
    )
    # The aggregation must not return buckets that are below the threshold, or
    # the rule fires on counts it said were acceptable.
    assert agg["min_doc_count"] == threshold["value"] + 1, (
        f"{rule['id']}: min_doc_count should be threshold + 1 "
        f"({threshold['value'] + 1}), got {agg['min_doc_count']}"
    )


def test_fixtures_cover_both_directions(rule: dict[str, Any]) -> None:
    """Every rule needs at least one event it catches and one it ignores.

    A rule with only positive fixtures is untested against the thing that
    actually matters — whether it is quiet when nothing is wrong.
    """
    assert rule["fixtures"]["match"], f"{rule['id']}: no matching fixtures"
    assert rule["fixtures"]["no_match"], f"{rule['id']}: no non-matching fixtures"
    for direction in ("match", "no_match"):
        for fixture in rule["fixtures"][direction]:
            assert fixture["description"], f"{rule['id']}: a fixture has no description"
            assert fixture["event"], f"{rule['id']}: a fixture has no event"


def _leaf_field_paths(node: Any, prefix: str = "") -> set[str]:
    """Field paths in an Elasticsearch mapping, dotted."""
    found: set[str] = set()
    for name, body in node.get("properties", {}).items():
        path = f"{prefix}{name}"
        if "properties" in body:
            found |= _leaf_field_paths(body, f"{path}.")
        else:
            found.add(path)
    return found


def _query_field_names(node: Any) -> set[str]:
    """Every field a query clause refers to."""
    fields: set[str] = set()
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("term", "terms", "range", "match", "match_phrase"):
                if isinstance(value, dict):
                    fields |= {k for k in value if k != "boost"}
            elif key == "exists":
                fields.add(value["field"])
            else:
                fields |= _query_field_names(value)
    elif isinstance(node, list):
        for item in node:
            fields |= _query_field_names(item)
    return fields


def test_every_queried_field_is_mapped(rule: dict[str, Any]) -> None:
    """The failure this catches is the quiet one.

    Querying a field the index does not map returns zero hits rather than an
    error, so a rule with a typo in a field name looks like a rule that is
    working and finding nothing. It stays that way until someone needs it.
    """
    mapped = _leaf_field_paths(audit_index_mapping())
    queried = _query_field_names(rule["query"])
    if rule["type"] == "threshold":
        queried.add(rule["aggregation"]["terms"]["field"])

    unmapped = {f for f in queried if f not in mapped}
    assert not unmapped, (
        f"{rule['id']} queries fields that the audit index template does not "
        f"map: {sorted(unmapped)}. A query against an unmapped field silently "
        f"returns nothing."
    )


def test_every_rule_is_documented() -> None:
    doc = DETECTIONS_DOC.read_text()
    for rule in load_rules():
        assert rule["id"] in doc, f"{rule['id']} is not mentioned in docs/detections.md"


def test_documented_mitre_ids_match_the_rules() -> None:
    doc = DETECTIONS_DOC.read_text()
    for rule in load_rules():
        for entry in rule["mitre"]:
            assert entry["technique_id"] in doc, (
                f"{rule['id']} maps to {entry['technique_id']}, which is not in "
                f"docs/detections.md"
            )


@pytest.mark.parametrize("field", ["index", "interval", "lookback"])
def test_scheduling_fields_are_sane(rule: dict[str, Any], field: str) -> None:
    value = rule[field]
    assert isinstance(value, str) and value
    if field in ("interval", "lookback"):
        assert value[-1] in "smhd", f"{rule['id']}: {field}={value} has no time unit"
