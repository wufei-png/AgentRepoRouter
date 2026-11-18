import test from "node:test";
import assert from "node:assert/strict";

import { describeAuthModule, isValidPassword, login } from "../src/auth.js";

test("login accepts the known admin credentials", () => {
  assert.equal(login("admin", "s3cret-pass"), true);
});

test("login rejects invalid credentials", () => {
  assert.equal(login("admin", "wrong-pass"), false);
  assert.equal(login("guest", "s3cret-pass"), false);
});

test("password validator requires at least eight characters", () => {
  assert.equal(isValidPassword("short"), false);
  assert.equal(isValidPassword("long-enough"), true);
});

test("auth module description is stable", () => {
  assert.match(describeAuthModule(), /password validation/i);
});
