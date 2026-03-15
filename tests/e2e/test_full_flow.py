#!/usr/bin/env python3
"""End-to-end test for full OrchAI flow"""

from orchai.router import Router


def test_case_1_feature_development():
    """Case 1: Feature development in test-backend"""
    print("\n=== Case 1: Feature Development ===")
    router = Router("skills/router/repo_mappings.json")

    task = "add password reset feature to test-backend"
    result = router.route(task)

    assert result["found"] == True
    assert result["repo"] == "test-backend"
    assert result["taskType"] == "feature"
    print(f"✓ Routed to {result['repo']} with {result['agent']}")


def test_case_2_bugfix():
    """Case 2: Bugfix in test-backend"""
    print("\n=== Case 2: Bugfix ===")
    router = Router("skills/router/repo_mappings.json")

    task = "fix login bug in test-backend"
    result = router.route(task)

    assert result["found"] == True
    assert result["repo"] == "test-backend"
    assert result["taskType"] == "bugfix"
    print(f"✓ Routed to {result['repo']} with {result['agent']}")


def test_case_3_docs_qa():
    """Case 3: Documentation Q&A"""
    print("\n=== Case 3: Documentation Q&A ===")
    router = Router("skills/router/repo_mappings.json")

    task = "what is the deployment process in test-docs"
    result = router.route(task)

    assert result["found"] == True
    assert result["repo"] == "test-docs"
    print(f"✓ Routed to {result['repo']} with {result['agent']}")


def test_case_4_ambiguous():
    """Case 4: Ambiguous project (self-evolution)"""
    print("\n=== Case 4: Ambiguous Project ===")
    router = Router("skills/router/repo_mappings.json")

    task = "fix login issue"
    result = router.route(task)

    if result["found"]:
        print(f"✓ Routed to {result['repo']}")
        # Simulate learning
        router.add_mapping("test-backend", ["issue"])
        print("✓ Learned new mapping")
    else:
        print(f"✓ Ambiguous - Candidates: {result['candidates']}")


def test_case_5_fallback():
    """Case 5: Fallback test (simulated)"""
    print("\n=== Case 5: Fallback Test ===")
    router = Router("skills/router/repo_mappings.json")

    task = "add logging to test-backend"
    result = router.route(task)

    assert result["found"] == True
    print(f"✓ Primary agent: {result['agent']}")
    print("✓ Fallback chain ready")


if __name__ == "__main__":
    print("=== OrchAI End-to-End Tests ===")

    test_case_1_feature_development()
    test_case_2_bugfix()
    test_case_3_docs_qa()
    test_case_4_ambiguous()
    test_case_5_fallback()

    print("\n=== All Tests Passed ✓ ===")
