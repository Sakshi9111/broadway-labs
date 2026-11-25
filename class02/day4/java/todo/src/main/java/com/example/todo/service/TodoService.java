package com.example.todo.service;

import com.example.todo.exception.TodoNotFoundException;
import com.example.todo.model.Todo;
import com.example.todo.model.TodoRequest;
import com.example.todo.repository.TodoRepository;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class TodoService {

    private static final Logger log = LoggerFactory.getLogger(TodoService.class);

    private final TodoRepository repo;

    public TodoService(TodoRepository repo) {
        this.repo = repo;
    }

    public List<Todo> findAll(Boolean done) {
        return done == null ? repo.findAll() : repo.findByDone(done);
    }

    public Todo findById(Long id) {
        return repo.findById(id).orElseThrow(() -> new TodoNotFoundException(id));
    }

    public Todo create(TodoRequest request) {
        Todo saved = repo.save(new Todo(request.title()));
        log.info("Created todo {}", saved.getId());
        return saved;
    }

    public Todo update(Long id, TodoRequest request) {
        Todo todo = findById(id);
        todo.setTitle(request.title());
        if (request.done() != null) {
            todo.setDone(request.done());
        }
        return repo.save(todo);
    }

    public void delete(Long id) {
        repo.delete(findById(id));
        log.info("Deleted todo {}", id);
    }
}