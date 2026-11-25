package com.example.todo.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TodoRequest(
        @NotBlank(message = "title is required")
        @Size(max = 100, message = "title must be 100 characters or less")
        String title,
        Boolean done) {}