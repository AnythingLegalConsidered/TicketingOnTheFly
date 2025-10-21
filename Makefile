# Ticketing Auto - Makefile
# Unified interface for all operations

# Configuration
COMPOSE_BASE = docker-compose -f docker-compose.yml
COMPOSE_DEV = $(COMPOSE_BASE) -f docker-compose.override.yml
COMPOSE_PROD = $(COMPOSE_BASE) -f docker-compose.prod.yml

# Load .env file and export variables
-include .env
export

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m

# Default target
.PHONY: help deploy-prod deploy-dev configure start stop restart backup restore update logs clean validate test docs ci all destroy status copy-env

# Default target
help:
	@echo "${BLUE}=== Ticketing Auto - Help ===${NC}"
	@echo "Available targets:"
	@echo "  ${GREEN}make deploy-prod${NC}    - Deploy production environment (Postfix)"
	@echo "  ${GREEN}make deploy-dev${NC}     - Deploy development environment (MailHog)"
	@echo "  ${GREEN}make configure${NC}      - Run post-deployment configuration"
	@echo "  ${GREEN}make start${NC}          - Start all services"
	@echo "  ${GREEN}make stop${NC}           - Stop all services"
	@echo "  ${GREEN}make restart${NC}        - Restart all services"
	@echo "  ${GREEN}make backup${NC}         - Perform backup of all data"
	@echo "  ${GREEN}make restore${NC}        - Restore from backup"
	@echo "  ${GREEN}make update${NC}         - Update container images to latest versions"
	@echo "  ${GREEN}make logs${NC}           - View logs of all services"
	@echo "  ${GREEN}make clean${NC}          - Remove all Docker resources"
	@echo "  ${GREEN}make validate${NC}       - Validate docker-compose files"
	@echo "  ${GREEN}make test${NC}           - Run integration tests"
	@echo "  ${GREEN}make docs${NC}           - Generate documentation"
	@echo "  ${GREEN}make ci${NC}             - Run CI/CD pipeline"
	@echo "  ${GREEN}make all${NC}            - Deploy + configure + validate"
	@echo "  ${GREEN}make status${NC}         - Show service status"
	@echo "  ${GREEN}make copy-env${NC}       - Copy .env.example to .env and fill in values"
	@echo "  ${RED}make destroy${NC}          - Destroy all resources (DANGEROUS)"
	@echo ""
	@echo "Environment variables (copy .env.example to .env and fill in values)"
	@echo "  TRAEFIK_DOMAIN: Base domain for all services URLs"
	@echo "  TRAEFIK_EMAIL: Email for notifications"
	@echo "  TRAEFIK_ACME_EMAIL: Email for Let's Encrypt certificates"
	@echo "  BACKUP_ENCRYPTION_KEY: Encryption key for backups"
	@echo ""
	@echo "Examples:"
	@echo "  ${GREEN}make deploy-dev${NC} && ${GREEN}make configure${NC}"
	@echo "  ${GREEN}make deploy-prod${NC} && ${GREEN}make backup${NC}"
	@echo "  ${GREEN}make start${NC} && ${GREEN}make logs${NC}"
	@echo "  ${GREEN}make clean${NC} && ${GREEN}make help${NC}"
	@echo "  ${GREEN}make all${NC}"
	@echo "  ${RED}make destroy${NC}"
	@echo "${BLUE}===========================${NC}"

# Deploy production environment
deploy-prod:
	@echo "${BLUE}=== Deploying Production Environment ===${NC}"
	@echo "Using Postfix for production email sending"
	@$(COMPOSE_PROD) up -d
	@echo "${GREEN}Production environment deployed!${NC}"

# Deploy development environment
deploy-dev:
	@echo "${BLUE}=== Deploying Development Environment ===${NC}"
	@echo "Using MailHog for email testing"
	@$(COMPOSE_DEV) up -d
	@echo "${GREEN}Development environment deployed!${NC}"

# Run post-deployment configuration
# This is now mostly automatic. Zammad LDAP config might still be needed.
configure:
	@echo "${BLUE}=== Running Post-Deployment Configuration ===${NC}"
	@echo "Waiting for services to be healthy..."
	@sleep 30 # Simple wait for services to initialize
	@echo "Applying Zammad LDAP configuration..."
	@docker exec zammad-railsserver /opt/zammad/bin/rails runner 'load "/opt/zammad/config/initializers/ldap.rb"'
	@echo "${GREEN}Configuration completed!${NC}"

# Stop all services
stop:
	@echo "${BLUE}=== Stopping All Services (uses last deployment context) ===${NC}"
	@docker-compose down --remove-orphans
	@echo "${GREEN}All services stopped!${NC}"

# Restart all services
restart:
	@echo "${BLUE}=== Restarting All Services (uses last deployment context) ===${NC}"
	@docker-compose restart
	@echo "${GREEN}All services restarted!${NC}"

# Perform backup
backup:
	@echo "${BLUE}=== Performing Backup ===${NC}"
	@BACKUP_DIR="backup/$$(date +%Y%m%d_%H%M%S)"
	@mkdir -p "$${BACKUP_DIR}"
	@echo "Backing up databases..."
	@docker exec zammad-db pg_dump -U postgres zammad_production > "$${BACKUP_DIR}/zammad_dump.sql"
	@docker exec ocs-db mysqldump -u root -p"$$MARIADB_ROOT_PASSWORD" ocsweb > "$${BACKUP_DIR}/ocs_dump.sql"
	@echo "Backing up volumes..."
	@docker run --rm -v ticketing_zammad_data:/source -v "$$(pwd)/$${BACKUP_DIR}":/dest alpine tar -czf "/dest/zammad_data.tar.gz" -C /source .
	@docker run --rm -v ticketing_ocs_db_data:/source -v "$$(pwd)/$${BACKUP_DIR}":/dest alpine tar -czf "/dest/ocs_data.tar.gz" -C /source .
	@echo "Encrypting backup files..."
	@gpg --batch --yes --passphrase "$$BACKUP_ENCRYPTION_KEY" -c "$${BACKUP_DIR}/zammad_dump.sql"
	@gpg --batch --yes --passphrase "$$BACKUP_ENCRYPTION_KEY" -c "$${BACKUP_DIR}/ocs_dump.sql"
	@echo "${GREEN}Backup completed and encrypted in $${BACKUP_DIR}${NC}"

# Restore from backup
restore:
	@echo "${BLUE}=== Restore from Backup ===${NC}"
	@echo "Available backups:"
	@ls -la backup/
	@echo "Usage: make restore BACKUP_DIR=backup/20240101_120000"
	@echo "Example: make restore BACKUP_DIR=backup/20240101_120000"
	@echo "${YELLOW}Warning: This will overwrite current data!${NC}"

# Update container images
update:
	@echo "${BLUE}=== Updating Container Images (uses last deployment context) ===${NC}"
	@docker-compose pull
	@echo "${GREEN}Images updated to latest versions!${NC}"

# View logs
logs:
	@echo "${BLUE}=== Viewing Logs (uses last deployment context) ===${NC}"
	@docker-compose logs -f

# Copy .env.example to .env
copy-env:
	@echo "${BLUE}=== Copying Environment File ===${NC}"
	@cp .env.example .env
	@echo "${YELLOW}Please fill in the .env file with your values${NC}"

# Clean all Docker resources
clean:
	@echo "${RED}=== Cleaning All Docker Resources ===${NC}"
	@echo "${YELLOW}This will remove all containers, networks, volumes, and images${NC}"
	@$(COMPOSE_DEV) down -v --rmi all --remove-orphans
	@$(COMPOSE_PROD) down -v --rmi all --remove-orphans
	@docker network prune -f
	@docker volume prune -f
	@echo "${GREEN}All Docker resources cleaned!${NC}"

# Validate docker-compose files
validate:
	@echo "${BLUE}=== Validating Docker Compose Files ===${NC}"
	@$(COMPOSE_BASE) config > /dev/null
	@$(COMPOSE_DEV) config > /dev/null
	@$(COMPOSE_PROD) config > /dev/null
	@echo "${GREEN}All docker-compose files are valid!${NC}"

# Run integration tests
test:
	@echo "${BLUE}=== Running Integration Tests ===${NC}"
	@echo "Testing service connectivity..."
	@echo "Testing Traefik routing..."
	@curl -s -o /dev/null -w "%{http_code}" https://traefik.${TRAEFIK_DOMAIN} > /dev/null
	@echo "Testing service health..."
	@docker ps --filter "status=running" | grep -q "traefik"
	@docker ps --filter "status=running" | grep -q "zammad"
	@docker ps --filter "status=running" | grep -q "grafana"
	@echo "${GREEN}All services are running and healthy!${NC}"

# Generate documentation
docs:
	@echo "${BLUE}=== Generate Documentation ===${NC}"
	@mkdir -p docs/generated
	@docker run --rm -v docs/generated:/output pandoc/latex:2.19 -f markdown -t html5 README.md -o docs/generated/index.html
	@echo "${GREEN}Documentation generated!${NC}"

# Run CI/CD pipeline
ci:
	@echo "${BLUE}=== Running CI/CD Pipeline ===${NC}"
	@make validate
	@make test
	@make deploy-dev
	@make configure
	@make backup
	@make validate
	@echo "${GREEN}CI/CD pipeline completed!${NC}"

# Deploy + configure + validate
all:
	@make deploy-dev
	@make configure
	@make validate
	@echo "${GREEN}All operations completed!${NC}"

# Destroy all resources (DANGEROUS)
destroy:
	@echo "${RED}=== DESTROYING ALL RESOURCES ===${NC}"
	@read -p "Are you sure? This will delete all data. (y/N) " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "Destroying development stack..."; \
		$(COMPOSE_DEV) down -v --rmi all --remove-orphans; \
		echo "Destroying production stack..."; \
		$(COMPOSE_PROD) down -v --rmi all --remove-orphans; \
		echo "Removing leftover data..."; \
		rm -rf backup/*; \
		rm -rf docs/generated/*; \
		echo "${RED}All resources destroyed!${NC}"; \
	else \
		echo "Destroy operation cancelled."; \
	fi

# Show service status
status:
	@echo "${BLUE}=== Service Status ===${NC}"
	@docker ps --filter "name=ticketing_*" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo "${BLUE}=== Volume Status ===${NC}"
	@docker volume ls --filter "name=ticketing_*"
	@echo "${BLUE}=== Network Status ===${NC}"
	@docker network ls --filter "name=ticketing_*"
	@echo "${GREEN}Status check completed!${NC}"
