const express = require("express");
const fs = require("fs");
const path = require("path");
const { TodoStore } = require("./store");

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || "0.0.0.0";
const DATA_FILE = process.env.DATA_FILE || path.join(process.cwd(), "data", "todos.json");
const store = new TodoStore(DATA_FILE);

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "public")));

// dist/build-info.json only exists after "npm run build"
function buildInfo() {
  try {
    const b = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "build-info.json"), "utf8"));
    return `v${b.version} built ${b.builtAt}`;
  } catch {
    return "not built (running from src/ in dev mode)";
  }
}

app.get("/api/info", (req, res) => {
  res.json({ runtime: `Node.js ${process.version}`, build: buildInfo() });
});
app.get("/api/todos", (req, res) => res.json(store.all()));
app.post("/api/todos", (req, res) => {
  const title = String((req.body && req.body.title) || "").trim();
  if (!title) return res.status(400).json({ error: "title is required" });
  res.status(201).json(store.add(title));
});
app.patch("/api/todos/:id", (req, res) => {
  const todo = store.toggle(Number(req.params.id));
  if (!todo) return res.status(404).json({ error: "not found" });
  res.json(todo);
});
app.delete("/api/todos/:id", (req, res) => {
  if (!store.remove(Number(req.params.id))) return res.status(404).json({ error: "not found" });
  res.json({ ok: true });
});

app.listen(PORT, HOST, () => console.log(`Todo app listening on http://${HOST}:${PORT}`));
