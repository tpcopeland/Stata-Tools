"""Tests for pitfalls.py — Stata programming pitfalls library."""

import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.parent / "tools"
sys.path.insert(0, str(TOOLS_DIR))

from pitfalls import get_pitfall, search_pitfalls, list_pitfalls


def test_get_pitfall_found():
    """Test getting a pitfall that exists."""
    result = get_pitfall("macro_name_truncation")
    assert result is not None
    assert result["id"] == "macro_name_truncation"
    assert "description" in result
    assert "title" in result


def test_get_pitfall_not_found():
    """Test getting a pitfall that doesn't exist."""
    result = get_pitfall("nonexistent_pitfall_xyz")
    assert result is None


def test_get_pitfall_case_insensitive():
    """Test that lookup is case-insensitive."""
    result = get_pitfall("MACRO_NAME_TRUNCATION")
    assert result is not None


def test_search_pitfalls_keyword():
    """Test searching pitfalls by keyword."""
    results = search_pitfalls("macro")
    assert isinstance(results, list)
    assert len(results) > 0
    # macro_name_truncation should be in results
    ids = [r["id"] for r in results]
    assert "macro_name_truncation" in ids


def test_search_pitfalls_description():
    """Test searching matches description text."""
    results = search_pitfalls("truncate")
    assert len(results) > 0


def test_search_pitfalls_limit():
    """Test search respects limit."""
    results = search_pitfalls("a", limit=2)
    assert len(results) <= 2


def test_search_pitfalls_no_results():
    """Test search with no matches."""
    results = search_pitfalls("xyznonexistent")
    assert results == []


def test_list_pitfalls_all():
    """Test listing all pitfalls."""
    results = list_pitfalls()
    assert isinstance(results, list)
    assert len(results) >= 9  # We seeded 9 pitfalls
    for r in results:
        assert "id" in r
        assert "title" in r
        assert "category" in r


def test_list_pitfalls_filtered():
    """Test listing pitfalls by category."""
    results = list_pitfalls(category="macro")
    assert len(results) > 0
    for r in results:
        assert r["category"] == "macro"


def test_list_pitfalls_unknown_category():
    """Test listing with unknown category returns empty."""
    results = list_pitfalls(category="nonexistent_category")
    assert results == []


def test_all_pitfalls_have_required_fields():
    """Test that all pitfalls have required fields."""
    results = list_pitfalls()
    for r in results:
        pitfall = get_pitfall(r["id"])
        assert pitfall is not None
        assert "id" in pitfall
        assert "title" in pitfall
        assert "category" in pitfall
        assert "description" in pitfall
        assert "keywords" in pitfall
        assert len(pitfall["description"]) > 0


def test_pitfall_examples():
    """Test that pitfalls have example fields."""
    pitfall = get_pitfall("macro_name_truncation")
    assert "example_wrong" in pitfall
    assert "example_right" in pitfall


if __name__ == "__main__":
    test_get_pitfall_found()
    test_get_pitfall_not_found()
    test_get_pitfall_case_insensitive()
    test_search_pitfalls_keyword()
    test_search_pitfalls_description()
    test_search_pitfalls_limit()
    test_search_pitfalls_no_results()
    test_list_pitfalls_all()
    test_list_pitfalls_filtered()
    test_list_pitfalls_unknown_category()
    test_all_pitfalls_have_required_fields()
    test_pitfall_examples()
    print("All pitfall tests passed!")
