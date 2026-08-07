"""Shared loading for the detection rule tests."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
RULES_DIR = REPO_ROOT / "security" / "detections"
DETECTIONS_DOC = REPO_ROOT / "docs" / "detections.md"
ILM_MANIFEST = REPO_ROOT / "kubernetes" / "base" / "ilm" / "policies.yaml"

VALID_SEVERITIES = {"low", "medium", "high", "critical"}
VALID_TYPES = {"query", "threshold"}


def load_rules() -> list[dict[str, Any]]:
    """Every rule definition, sorted by id."""
    rules = []
    for path in sorted(RULES_DIR.glob("*.yaml")):
        with path.open() as fh:
            rule = yaml.safe_load(fh)
        rule["_path"] = path
        rules.append(rule)
    return sorted(rules, key=lambda r: r["id"])


def audit_index_mapping() -> dict[str, Any]:
    """The real audit index mapping, read out of the Kubernetes manifest.

    The tests run against the same mappings the cluster uses. Keeping a second
    copy here would let the two drift, and a detection that works against a
    hand-written test mapping but not against the deployed one is worse than no
    test at all.
    """
    with ILM_MANIFEST.open() as fh:
        manifest = yaml.safe_load(fh)
    template = json.loads(manifest["data"]["template-kubernetes-audit.json"])
    return template["template"]["mappings"]


@pytest.fixture(scope="session")
def rules() -> list[dict[str, Any]]:
    return load_rules()


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    """Parametrise any test taking a `rule` argument over every rule."""
    if "rule" in metafunc.fixturenames:
        loaded = load_rules()
        metafunc.parametrize("rule", loaded, ids=[r["id"] for r in loaded])
