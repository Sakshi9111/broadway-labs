const test = require("node:test");
const assert = require("node:assert");
const os = require("os");
const path = require("path");
const { TodoStore } = require("../src/store");

function newStore() {
  return new TodoStore(path.join(os.tmpdir(), `todo-${Date.now()}-${Math.random()}.json`));
}

test("add creates a todo that is not done", () => {
  const s = newStore();
  const t = s.add("learn nginx");
  assert.strictEqual(t.title, "learn nginx");
  assert.strictEqual(t.done, false);
});

test("toggle flips done", () => {
  const s = newStore();
  const t = s.add("learn docker");
  assert.strictEqual(s.toggle(t.id).done, true);
  assert.strictEqual(s.toggle(t.id).done, false);
});

test("remove deletes a todo", () => {
  const s = newStore();
  const t = s.add("temp");
  assert.strictEqual(s.remove(t.id), true);
  assert.strictEqual(s.all().length, 0);
  assert.strictEqual(s.remove(999), false);
});
