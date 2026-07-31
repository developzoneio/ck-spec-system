export class InMemoryStore {
  #todos = new Map();
  #nextId = 1;

  nextId() {
    return String(this.#nextId++);
  }

  save(todo) {
    this.#todos.set(todo.id, todo);
    return todo;
  }

  get(id) {
    return this.#todos.get(id);
  }

  list() {
    return [...this.#todos.values()];
  }

  update(todo) {
    if (!this.#todos.has(todo.id)) {
      throw new Error(`Cannot update unknown todo: ${todo.id}`);
    }
    this.#todos.set(todo.id, todo);
    return todo;
  }
}
