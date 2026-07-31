import { TodoService } from './application/todo-service.js';
import { InMemoryStore } from './infrastructure/store.js';

const service = new TodoService(new InMemoryStore());

service.addTodo('Write the specwright example fixture');
service.addTodo('Run /sd:feature end to end');

const [first] = service.listTodos();
service.completeTodo(first.id);

for (const todo of service.listTodos()) {
  console.log(`[${todo.done ? 'x' : ' '}] ${todo.title}`);
}
