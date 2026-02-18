"""Tests for snippets.py tool functions."""

import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))

from snippets import get_snippet, search_snippets, list_snippets, SNIPPETS


def test_get_snippet_found():
    """Test getting a snippet that exists."""
    result = get_snippet("marksample_basic")
    assert result is not None
    assert result["name"] == "marksample_basic"
    assert "code" in result
    assert "purpose" in result


def test_get_snippet_not_found():
    """Test getting a snippet that doesn't exist."""
    result = get_snippet("nonexistent_snippet_xyz")
    assert result is None


def test_search_snippets():
    """Test searching snippets."""
    results = search_snippets("loop")
    assert isinstance(results, list)
    assert len(results) > 0
    for r in results:
        assert "name" in r
        assert "purpose" in r


def test_search_snippets_limit():
    """Test search respects limit."""
    results = search_snippets("a", limit=2)
    assert len(results) <= 2


def test_list_snippets():
    """Test listing all snippets."""
    results = list_snippets()
    assert isinstance(results, list)
    assert len(results) == len(SNIPPETS)
    for r in results:
        assert "name" in r
        assert "purpose" in r


def test_list_snippets_filtered():
    """Test listing snippets by category."""
    results = list_snippets(category="loop")
    assert isinstance(results, list)
    assert len(results) > 0
    for r in results:
        assert "loop" in [k.lower() for k in r.get("keywords", [])]


def test_all_snippets_have_required_fields():
    """Test that all built-in snippets have required fields."""
    for name, snippet in SNIPPETS.items():
        assert "name" in snippet, f"Snippet {name} missing 'name'"
        assert "purpose" in snippet, f"Snippet {name} missing 'purpose'"
        assert "code" in snippet, f"Snippet {name} missing 'code'"
        assert "keywords" in snippet, f"Snippet {name} missing 'keywords'"
        assert len(snippet["code"]) > 0, f"Snippet {name} has empty code"


if __name__ == "__main__":
    test_get_snippet_found()
    test_get_snippet_not_found()
    test_search_snippets()
    test_search_snippets_limit()
    test_list_snippets()
    test_list_snippets_filtered()
    test_all_snippets_have_required_fields()
    print("All snippet tests passed!")
