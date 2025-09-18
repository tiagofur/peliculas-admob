# DATABASE SCHEMA

## Overview

This document outlines the database schema for the peliculas-admob application. It includes details about the tables, their relationships, and the data types used. The schema is designed to support the application's functionality, including movie browsing, user management, and offline capabilities.

## Tables

### 1. Users

- **Table Name**: `users`
- **Description**: Stores user information and authentication details.
- **Columns**:
  - `id`: UUID (Primary Key)
  - `username`: VARCHAR(50) (Unique)
  - `email`: VARCHAR(100) (Unique)
  - `password_hash`: VARCHAR(255)
  - `created_at`: TIMESTAMP
  - `updated_at`: TIMESTAMP

### 2. Movies

- **Table Name**: `movies`
- **Description**: Contains information about movies available in the application.
- **Columns**:
  - `id`: UUID (Primary Key)
  - `title`: VARCHAR(255)
  - `description`: TEXT
  - `release_date`: DATE
  - `rating`: FLOAT
  - `poster_url`: VARCHAR(255)
  - `created_at`: TIMESTAMP
  - `updated_at`: TIMESTAMP

### 3. Watchlist

- **Table Name**: `watchlist`
- **Description**: Links users to their selected movies for viewing later.
- **Columns**:
  - `id`: UUID (Primary Key)
  - `user_id`: UUID (Foreign Key referencing `users.id`)
  - `movie_id`: UUID (Foreign Key referencing `movies.id`)
  - `added_at`: TIMESTAMP

### 4. Reviews

- **Table Name**: `reviews`
- **Description**: Stores user reviews for movies.
- **Columns**:
  - `id`: UUID (Primary Key)
  - `user_id`: UUID (Foreign Key referencing `users.id`)
  - `movie_id`: UUID (Foreign Key referencing `movies.id`)
  - `rating`: INT (1-5)
  - `comment`: TEXT
  - `created_at`: TIMESTAMP
  - `updated_at`: TIMESTAMP

### 5. Offline Cache

- **Table Name**: `offline_cache`
- **Description**: Stores data for offline access.
- **Columns**:
  - `id`: UUID (Primary Key)
  - `data`: JSONB
  - `created_at`: TIMESTAMP
  - `updated_at`: TIMESTAMP

## Relationships

- **Users to Watchlist**: One-to-Many
  - A user can have multiple entries in the watchlist.
  
- **Users to Reviews**: One-to-Many
  - A user can write multiple reviews for different movies.

- **Movies to Watchlist**: One-to-Many
  - A movie can be added to multiple users' watchlists.

- **Movies to Reviews**: One-to-Many
  - A movie can have multiple reviews from different users.

## Data Types

- **UUID**: Universally Unique Identifier for primary keys.
- **VARCHAR**: Variable-length character string.
- **TEXT**: Large text field for descriptions and comments.
- **FLOAT**: Floating-point number for ratings.
- **DATE**: Date type for release dates.
- **TIMESTAMP**: Date and time for tracking creation and updates.
- **JSONB**: Binary JSON format for storing structured data in the offline cache.

## Conclusion

This schema provides a robust foundation for the peliculas-admob application, supporting essential features such as user management, movie browsing, and offline capabilities. Future enhancements may include additional tables for features like user preferences, movie genres, and social sharing functionalities.