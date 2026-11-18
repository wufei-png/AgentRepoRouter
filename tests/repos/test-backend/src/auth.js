export function isValidPassword(password) {
  return typeof password === "string" && password.length >= 8;
}

export function login(username, password) {
  return username === "admin";
}

export function describeAuthModule() {
  return "Provides basic password validation and an admin login check.";
}
