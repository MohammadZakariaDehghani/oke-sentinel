"""Behavioural tests: do the rules actually match what they claim to?

Skipped unless ES_URL is set. The kind integration job in CI sets it, which is
what makes these run on every pull request against a real Elasticsearch rather
than a mock.

The approach for each rule is deliberately blunt:

  * build an index using the *deployed* audit mapping, read out of
    kubernetes/base/ilm/policies.yaml
  * index the `match` fixtures into one index and the `no_match` fixtures into
    another
  * run the rule's own query against both

A query rule must return every match fixture and nothing from the no_match
index. A threshold rule must produce at least one over-threshold bucket from
the match index and none from the no_match index.

Two separate indices rather than one with tagging, because a rule must not be
able to pass by matching a document the test added for bookkeeping.
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import pytest
from conftest import audit_index_mapping

httpx = pytest.importorskip(
    "httpx", reason="httpx is required for the Elasticsearch tests"
)

ES_URL = os.environ.get("ES_URL")
ES_USER = os.environ.get("ES_USER", "elastic")
ES_PASSWORD = os.environ.get("ES_PASSWORD", "")
# The CI cluster uses ECK's self-signed CA. Point ES_CA_CERT at it, or set
# ES_INSECURE=1 to skip verification against a throwaway kind cluster.
ES_CA_CERT = os.environ.get("ES_CA_CERT")
ES_INSECURE = os.environ.get("ES_INSECURE") == "1"

pytestmark = pytest.mark.skipif(
    not ES_URL,
    reason="ES_URL is not set; these tests need a running Elasticsearch",
)


@pytest.fixture(scope="session")
def client() -> Any:
    verify: Any = ES_CA_CERT if ES_CA_CERT else (not ES_INSECURE)
    with httpx.Client(
        base_url=ES_URL,
        auth=(ES_USER, ES_PASSWORD),
        verify=verify,
        timeout=60.0,
    ) as c:
        yield c


def _expand(fixtures: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Flatten fixtures into documents, honouring `repeat` and stamping times.

    Timestamps are spread across the last few minutes so that a rule with a
    lookback window sees them all, and so that documents are not identical.
    """
    now = datetime.now(timezone.utc)
    docs: list[dict[str, Any]] = []
    for fixture in fixtures:
        for i in range(int(fixture.get("repeat", 1))):
            doc = dict(fixture["event"])
            doc["@timestamp"] = (now - timedelta(seconds=30 + i)).isoformat()
            docs.append(doc)
    return docs


def _create_index(client: Any, name: str) -> None:
    response = client.put(
        f"/{name}",
        json={
            "settings": {"number_of_shards": 1, "number_of_replicas": 0},
            "mappings": audit_index_mapping(),
        },
    )
    assert response.status_code < 400, response.text


def _bulk_index(client: Any, name: str, docs: list[dict[str, Any]]) -> None:
    if not docs:
        return
    lines = []
    for doc in docs:
        lines.append('{"index":{}}')
        lines.append(json.dumps(doc))
    body = "\n".join(lines) + "\n"
    response = client.post(
        f"/{name}/_bulk?refresh=wait_for",
        content=body,
        headers={"Content-Type": "application/x-ndjson"},
    )
    assert response.status_code < 400, response.text
    payload = response.json()
    assert not payload.get("errors"), payload


def _search(client: Any, name: str, rule: dict[str, Any]) -> dict[str, Any]:
    body: dict[str, Any] = {
        "query": rule["query"],
        "size": 100,
        "track_total_hits": True,
    }
    if rule["type"] == "threshold":
        body["size"] = 0
        body["aggs"] = {"over_threshold": rule["aggregation"]}
    response = client.post(f"/{name}/_search", json=body)
    assert response.status_code < 400, response.text
    return response.json()


@pytest.fixture()
def indices(client: Any, rule: dict[str, Any]) -> Any:
    """A fresh pair of indices per rule, torn down afterwards."""
    suffix = uuid.uuid4().hex[:8]
    match_index = f"detections-test-{rule['id']}-match-{suffix}"
    no_match_index = f"detections-test-{rule['id']}-nomatch-{suffix}"
    for name in (match_index, no_match_index):
        _create_index(client, name)
    _bulk_index(client, match_index, _expand(rule["fixtures"]["match"]))
    _bulk_index(client, no_match_index, _expand(rule["fixtures"]["no_match"]))
    try:
        yield match_index, no_match_index
    finally:
        for name in (match_index, no_match_index):
            client.delete(f"/{name}", params={"ignore_unavailable": "true"})


def test_rule_matches_its_positive_fixtures(
    client: Any, rule: dict[str, Any], indices: tuple[str, str]
) -> None:
    match_index, _ = indices
    result = _search(client, match_index, rule)

    if rule["type"] == "threshold":
        buckets = result["aggregations"]["over_threshold"]["buckets"]
        assert buckets, (
            f"{rule['id']}: no identity crossed the threshold of "
            f"{rule['threshold']['value']} despite the matching fixtures"
        )
    else:
        expected = len(_expand(rule["fixtures"]["match"]))
        actual = result["hits"]["total"]["value"]
        assert actual == expected, (
            f"{rule['id']}: expected {expected} matches, got {actual}. "
            f"A rule that misses its own fixtures will miss the real thing."
        )


def test_rule_ignores_its_negative_fixtures(
    client: Any, rule: dict[str, Any], indices: tuple[str, str]
) -> None:
    _, no_match_index = indices
    result = _search(client, no_match_index, rule)

    if rule["type"] == "threshold":
        buckets = result["aggregations"]["over_threshold"]["buckets"]
        assert not buckets, (
            f"{rule['id']}: fired on events it is documented to ignore — "
            f"{[b['key'] for b in buckets]}"
        )
    else:
        hits = result["hits"]["hits"]
        assert not hits, (
            f"{rule['id']}: matched {len(hits)} event(s) it is documented to "
            f"ignore. This is the false positive the rule promised not to have."
        )
