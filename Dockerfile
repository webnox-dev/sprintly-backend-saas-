# Use the latest stable Dart SDK image
FROM dart:stable

# Set the working directory inside the container
WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the source code
COPY . .

# Expose the port your server will listen on
EXPOSE 8080

# Start the server using Dart
CMD ["dart", "run", "bin/server.dart"]
