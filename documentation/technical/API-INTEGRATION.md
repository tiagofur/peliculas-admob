# API Integration Documentation

## Overview

This document outlines the API integration process for the Peliculas-Admob application. It details the various endpoints used, the data handling mechanisms, and best practices for interacting with the APIs.

## API Endpoints

### 1. Supabase API

- **Base URL**: `https://your_supabase_url/rest/v1/`
- **Authentication**: Requires Bearer token for all requests.

#### Endpoints

- **Get Movies**
  - **Method**: GET
  - **Endpoint**: `/movies`
  - **Description**: Fetches a list of movies from the database.
  - **Response**: Returns a JSON array of movie objects.

- **Add Movie**
  - **Method**: POST
  - **Endpoint**: `/movies`
  - **Description**: Adds a new movie to the database.
  - **Request Body**: JSON object containing movie details (title, genre, release date, etc.).
  - **Response**: Returns the created movie object.

- **Update Movie**
  - **Method**: PATCH
  - **Endpoint**: `/movies/{id}`
  - **Description**: Updates an existing movie's details.
  - **Request Body**: JSON object with updated movie details.
  - **Response**: Returns the updated movie object.

- **Delete Movie**
  - **Method**: DELETE
  - **Endpoint**: `/movies/{id}`
  - **Description**: Deletes a movie from the database.
  - **Response**: Returns a success message.

### 2. The Movie Database (TMDB) API

- **Base URL**: `https://api.themoviedb.org/3/`
- **Authentication**: Requires API key.

#### Endpoints

- **Search Movies**
  - **Method**: GET
  - **Endpoint**: `/search/movie`
  - **Description**: Searches for movies based on a query.
  - **Query Parameters**: `query`, `api_key`
  - **Response**: Returns a JSON object with search results.

- **Get Movie Details**
  - **Method**: GET
  - **Endpoint**: `/movie/{id}`
  - **Description**: Fetches detailed information about a specific movie.
  - **Query Parameters**: `api_key`
  - **Response**: Returns a JSON object with movie details.

## Data Handling

### Request Handling

- Use `http` package for making API requests.
- Implement error handling for network issues and API errors.
- Validate response data before processing.

### Response Handling

- Parse JSON responses using `dart:convert`.
- Map JSON data to model classes for easier data manipulation.
- Handle null values and unexpected data formats gracefully.

## Best Practices

- **Rate Limiting**: Be mindful of API rate limits. Implement exponential backoff for retries.
- **Caching**: Use local storage (e.g., Hive or Isar) to cache frequently accessed data and reduce API calls.
- **Security**: Never expose API keys in the client-side code. Use environment variables to manage sensitive information.
- **Documentation**: Keep API documentation up to date with any changes in endpoints or data structures.

## Conclusion

This document serves as a guide for developers working on the Peliculas-Admob application to ensure consistent and efficient API integration. Following these guidelines will help maintain a robust and scalable application.