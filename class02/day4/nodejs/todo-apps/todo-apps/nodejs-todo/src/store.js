const fs = require("fs");
const path = require("path");

// Keeps todos in memory and saves them to a JSON file after every change.
class TodoStore {
  constructor(file) {
    this.file = file;
    fs.mkdirSync(path.dirname(file), { recursive: true });
    this.todos = this.load();
  }
  load() {
    try { return JSON.parse(fs.readFileSync(this.file, "utf8")); }
    catch { return []; }
  }
  save() {
    fs.writeFileSync(this.file, JSON.stringify(this.todos, null, 2));
  }
  all() { return this.todos; }
  add(title) {
    const id = this.todos.reduce((max, t) => Math.max(max, t.id), 0) + 1;
    const todo = { id, title, done: false };
    this.todos.push(todo);
    this.save();
    return todo;
  }
  toggle(id) {
    const todo = this.todos.find((t) => t.id === id);
    if (!todo) return null;
    todo.done = !todo.done;
    this.save();
    return todo;
  }
  remove(id) {
    const before = this.todos.length;
    this.todos = this.todos.filter((t) => t.id !== id);
    if (this.todos.length === before) return false;
    this.save();
    return true;
  }
}

module.exports = { TodoStore };
