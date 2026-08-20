.PHONY: up down logs api-test api-lint

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f api

api-test:
	cd services/api && npm test

api-lint:
	cd services/api && npm run typecheck

