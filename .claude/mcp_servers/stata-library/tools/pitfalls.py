#!/usr/bin/env python3
"""
Stata Programming Pitfalls Library

Lightweight system for tracking Stata programming pitfalls
discovered during development.
"""

import json
from pathlib import Path
from typing import Optional, List, Dict, Any

# Path to pitfalls data
DATA_DIR = Path(__file__).parent.parent / "data"
PITFALLS_FILE = DATA_DIR / "pitfalls.json"

# Cache loaded pitfalls
_pitfalls_cache: Optional[List[Dict[str, Any]]] = None


def _load_pitfalls() -> List[Dict[str, Any]]:
    """Load pitfalls from JSON file."""
    global _pitfalls_cache
    if _pitfalls_cache is not None:
        return _pitfalls_cache

    try:
        with open(PITFALLS_FILE) as f:
            _pitfalls_cache = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        _pitfalls_cache = []

    return _pitfalls_cache


def get_pitfall(name: str) -> Optional[Dict[str, Any]]:
    """
    Get a specific pitfall by ID.

    Args:
        name: Pitfall ID (e.g., "macro_name_truncation")

    Returns:
        Pitfall dictionary or None if not found.
    """
    pitfalls = _load_pitfalls()
    name_lower = name.lower()
    for p in pitfalls:
        if p["id"].lower() == name_lower:
            return p
    return None


def search_pitfalls(query: str, limit: int = 5) -> List[Dict[str, Any]]:
    """
    Search pitfalls by keyword.

    Args:
        query: Search term
        limit: Maximum results (default 5)

    Returns:
        List of matching pitfalls sorted by relevance.
    """
    pitfalls = _load_pitfalls()
    query_lower = query.lower()
    matches = []

    for p in pitfalls:
        score = 0

        if query_lower in p["id"].lower():
            score += 10
        if query_lower in p.get("title", "").lower():
            score += 8
        if query_lower in p.get("description", "").lower():
            score += 3
        for kw in p.get("keywords", []):
            if query_lower in kw.lower():
                score += 5

        if score > 0:
            matches.append((score, p))

    matches.sort(key=lambda x: x[0], reverse=True)
    return [m[1] for m in matches[:limit]]


def list_pitfalls(category: Optional[str] = None) -> List[Dict[str, Any]]:
    """
    List pitfalls, optionally filtered by category.

    Args:
        category: Filter by category (e.g., "macro", "display", "precision")

    Returns:
        List of pitfalls with id, title, and category.
    """
    pitfalls = _load_pitfalls()
    results = []

    for p in pitfalls:
        if category and p.get("category", "").lower() != category.lower():
            continue
        results.append({
            "id": p["id"],
            "title": p["title"],
            "category": p.get("category", ""),
            "keywords": p.get("keywords", []),
        })

    return sorted(results, key=lambda x: x["id"])
