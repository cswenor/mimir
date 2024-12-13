# Mimir

Mimir is a flexible and powerful indexer for AVM (Algorand Virtual Machine) blockchains, designed specifically to support networks like Voi. By combining multiple specialized components, Mimir provides a robust solution for indexing blockchain data with enhanced querying capabilities.

## Overview

Mimir integrates several key components to create a comprehensive indexing solution:

- **Follower Node**: A specialized blockchain node that synchronizes with the network in a controlled manner, advancing only when instructed.
- **Conduit**: A data processing layer that reads block information and manages node progression while writing to PostgreSQL.
- **Supabase**: A powerful PostgreSQL-based backend that provides:
  - Real-time subscriptions
  - Auto-generated REST API
  - Authentication and row-level security
  - GraphQL interface
  - Database management dashboard

This architecture provides several advantages over traditional indexers:

- Flexible querying capabilities through PostgreSQL
- Real-time data subscriptions
- Built-in authentication and authorization
- GraphQL and REST API endpoints
- Simple deployment and management

## Prerequisites

- Docker and Docker Compose
- Node.js 16 or higher
- Git

## Quick Start

1. Clone the repository:

    ```bash
    git clone https://github.com/cswenor/mimir.git
    cd mimir
    ```

2. Initialize the environment:

    ```bash
    ./bin/mimir init
    ```

    This command will:
    - Generate necessary environment variables
    - Create required configuration files
    - Set up data directories
    - Initialize the database schema

3. Start the services:

    ```bash
    ./bin/mimir start
    ```

4. Check the status of the Voi follower node:

    ```bash
    ./bin/mimir status
    ```

    This will display the current sync status and other node-related information.

Once running, Mimir will be indexing the blockchain and persisting data into the PostgreSQL database managed by Supabase.

## Accessing the Supabase Dashboard

Mimir provides a local Supabase dashboard for managing your database and settings. Once the services are running, you can access the dashboard at:

- **URL:** [http://localhost:8000](http://localhost:8000)

Use the Supabase dashboard user ID and password defined in the `.env` file (located in `mimir/supabase/.env`) to log in.

## Using the Mimir Command-Line Tool

Mimir includes a command-line utility `mimir` (located in `/bin/mimir`) to help you manage and maintain your indexing environment. Below are the available commands:

- **init**: Initialize or reinitialize the Mimir environment.
  
  ```bash
  ./bin/mimir init [OPTIONS]
  
  Options:
    -v    Verbose mode
  ```

- **start**: Start all Mimir-related services, including the follower node, Conduit, and Supabase.
  
  ```bash
  ./bin/mimir start
  ```

- **stop**: Stop all services cleanly.
  
  ```bash
  ./bin/mimir stop
  ```

- **reset**: Reset the Mimir environment. This removes existing data, configurations, and other stateful components. Use with caution.
  
  ```bash
  ./bin/mimir reset [OPTIONS]
  
  Options:
    -v    Verbose mode
    -f    Force reset (skip confirmation prompts)
  ```

- **status**: Check the status of the Voi node.
  
  ```bash
  ./bin/mimir status
  ```

- **help**: Display help and usage information about the `mimir` commands.
  
  ```bash
  ./bin/mimir help
  ```

## Project Structure

```
mimir/
├── algod-data/          # Follower node data directory
├── conduit-data/        # Conduit configuration and data
├── scripts/             # Setup and utility scripts
├── templates/           # Configuration templates
├── supabase/            # Supabase configuration, .env file, and services
├── bin/                 # Directory containing the mimir command-line tool
├── docker-compose.yml   # Main service orchestration
└── supabase/.env        # Environment configuration for Supabase and Mimir
```

## Configuration

Mimir uses a `.env` file located inside the `supabase` folder. The `mimir init` command will generate this file with secure defaults. Key configuration areas include:

- Node connection details
- Database credentials
- JWT secrets
- API keys
- Service endpoints

## Advanced Usage

For advanced use of Mimir and its integrations with Supabase, please refer to the [Supabase documentation](https://supabase.com/docs).

### Custom Queries

Mimir stores blockchain data in PostgreSQL, allowing for complex custom queries. You can:

- Create custom views
- Set up materialized views for performance
- Implement custom functions
- Use full-text search capabilities

### Real-time Subscriptions

Subscribe to real-time updates using Supabase's real-time feature:

```javascript
const subscription = supabase
  .from("transactions")
  .on("INSERT", handleNewTransaction)
  .subscribe();
```

### Authentication

Mimir includes built-in authentication through Supabase, supporting:

- JWT-based authentication
- Row-level security policies
- Multiple auth providers
- Role-based access control

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Development

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgments

- [Voi Network](https://voi.network/) - For their support and collaboration
- [Algorand](https://www.algorand.com/) - For the underlying AVM technology
- [Supabase](https://supabase.com/) - For their excellent database platform

## Support

For support, please:

- Open an issue in the GitHub repository