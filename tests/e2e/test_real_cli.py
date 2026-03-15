"""End-to-end tests with real CLI execution"""

import pytest

from orchai.acp_adapter import ACPAdapter
from orchai.validator import ResultValidator

TEST_BACKEND = "tests/repos/test-backend"


@pytest.mark.asyncio
async def test_bugfix_with_validation():
    adapter = ACPAdapter()
    validator = ResultValidator(TEST_BACKEND)
    validator.capture_initial_state(files_to_watch=["src/auth.py"])

    result = await adapter.execute_agent(
        agent="opencode",
        repo=TEST_BACKEND,
        task="fix the login bug in src/auth.py where login always returns True without validating credentials",
    )

    validation = validator.validate_bugfix_or_feature(result)

    print("\n=== Bugfix Validation ===")
    print(f"Output valid: {validation['output_valid']}")
    print(f"Files modified: {validation['files_modified']}")
    print(f"Changed files: {validation['changed_files']}")
    print(f"Event count: {validation['event_count']}")

    if validation["output_errors"]:
        print(f"Errors: {validation['output_errors']}")

    assert validation["valid"], f"Bugfix validation failed: {validation}"
    assert validation["output_valid"], "Output contains errors"
    assert validation["files_modified"], "No files were modified"


@pytest.mark.asyncio
async def test_qa_with_validation():
    adapter = ACPAdapter()
    validator = ResultValidator(TEST_BACKEND)
    validator.capture_initial_state()

    result = await adapter.execute_agent(
        agent="opencode",
        repo=TEST_BACKEND,
        task="describe what the auth.py file does",
    )

    validation = validator.validate_qa(result)

    print("\n=== QA Validation ===")
    print(f"Output valid: {validation['output_valid']}")
    print(f"Files unchanged: {validation['files_unchanged']}")
    print(f"Event count: {validation['event_count']}")

    if validation["output_errors"]:
        print(f"Errors: {validation['output_errors']}")
    if validation["changed_files"]:
        print(f"Changed files: {validation['changed_files']}")

    assert validation["valid"], f"QA validation failed: {validation}"
    assert validation["output_valid"], "Output contains errors"
    assert validation["files_unchanged"], "Files were modified (should be read-only)"


@pytest.mark.asyncio
async def test_feature_with_validation():
    adapter = ACPAdapter()
    validator = ResultValidator(TEST_BACKEND)
    validator.capture_initial_state(files_to_watch=["src/auth.py"])

    result = await adapter.execute_agent(
        agent="opencode",
        repo=TEST_BACKEND,
        task="add a logout function to src/auth.py",
    )

    validation = validator.validate_bugfix_or_feature(result)

    print("\n=== Feature Validation ===")
    print(f"Output valid: {validation['output_valid']}")
    print(f"Files modified: {validation['files_modified']}")
    print(f"Changed files: {validation['changed_files']}")
    print(f"Event count: {validation['event_count']}")

    if validation["output_errors"]:
        print(f"Errors: {validation['output_errors']}")

    assert validation["valid"], f"Feature validation failed: {validation}"
    assert validation["output_valid"], "Output contains errors"
    assert validation["files_modified"], "No files were modified"


@pytest.mark.asyncio
async def test_oneshot_no_history():
    adapter = ACPAdapter()

    first_result = await adapter.execute_agent(
        agent="opencode",
        repo=TEST_BACKEND,
        task="remember this phrase: MAGIC_TOKEN_12345",
    )

    assert first_result["status"] == "completed"
    assert len(first_result["events"]) > 0

    second_result = await adapter.execute_agent(
        agent="opencode",
        repo=TEST_BACKEND,
        task="what phrase did I ask you to remember in our previous conversation?",
    )

    combined_output = " ".join(
        str(e.get("message", "")) for e in second_result.get("events", [])
    ).lower()

    has_magic_token = (
        "magic_token_12345" in combined_output or "MAGIC_TOKEN_12345" in combined_output
    )

    print("\n=== One-shot No History Test ===")
    print(f"First call events: {len(first_result['events'])}")
    print(f"Second call events: {len(second_result['events'])}")
    print(f"Combined output: {combined_output[:200]}...")
    print(f"Has magic token: {has_magic_token}")

    assert not has_magic_token, (
        "LLM remembered previous conversation - one-shot mode not working! "
        f"Output: {combined_output}"
    )
