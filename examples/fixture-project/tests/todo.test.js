import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  createTodo,
  completeTodo,
  validateTitle,
  InvalidTitleError,
  validatePriority,
  InvalidPriorityError,
} from '../src/domain/todo.js';

test('createTodo builds a todo with done=false', () => {
  const todo = createTodo({ id: '1', title: 'Write tests' });
  assert.equal(todo.id, '1');
  assert.equal(todo.title, 'Write tests');
  assert.equal(todo.done, false);
});

test('createTodo rejects an empty title', () => {
  assert.throws(() => createTodo({ id: '1', title: '   ' }), InvalidTitleError);
});

test('completeTodo returns a new object with done=true', () => {
  const todo = createTodo({ id: '1', title: 'Write tests' });
  const completed = completeTodo(todo);
  assert.equal(completed.done, true);
  assert.equal(todo.done, false, 'original todo is left untouched');
});

test('validateTitle rejects a non-string title', () => {
  assert.throws(() => validateTitle(42), InvalidTitleError);
});

test('createTodo accepts each allowed priority', () => {
  for (const priority of ['low', 'medium', 'high']) {
    const todo = createTodo({ id: '1', title: 'Write tests', priority });
    assert.equal(todo.priority, priority);
  }
});

test('createTodo defaults priority to medium when omitted or undefined', () => {
  const withoutPriority = createTodo({ id: '1', title: 'Write tests' });
  assert.equal(withoutPriority.priority, 'medium');

  const withUndefinedPriority = createTodo({ id: '1', title: 'Write tests', priority: undefined });
  assert.equal(withUndefinedPriority.priority, 'medium');
});

test('createTodo rejects a priority outside the allowed set', () => {
  for (const priority of ['urgent', 'HIGH', '', null, 42]) {
    assert.throws(() => createTodo({ id: '1', title: 'Write tests', priority }), InvalidPriorityError);
  }
});

test('createTodo rejects an invalid title even when the priority is also invalid', () => {
  assert.throws(() => createTodo({ id: '1', title: '   ', priority: 'urgent' }), InvalidTitleError);
});

test('validatePriority does not throw for an allowed priority', () => {
  assert.doesNotThrow(() => validatePriority('high'));
});

test('validatePriority rejects a priority outside the allowed set', () => {
  assert.throws(() => validatePriority('urgent'), InvalidPriorityError);
});
