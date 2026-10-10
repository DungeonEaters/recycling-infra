.PHONY: up down logs test reset web mobile dev-api dev-web dev-mobile test-local

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

test:
	docker compose run --rm --no-deps -e DATABASE_URL=sqlite+pysqlite:///:memory: api pytest -q

reset:
	docker compose down -v && docker compose up -d --build

web:
	docker compose up -d --build web

mobile:
	docker compose up -d --build mobile

# Targets used inside the dev container (DATABASE_URL points to the `db` service).
dev-api:
	cd ../recycling-backend && .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-web:
	cd ../recycling-web && npm run dev

dev-mobile:
	cd ../recycling-mobile && npm run dev

test-local:
	cd ../recycling-backend && DATABASE_URL=sqlite+pysqlite:///:memory: .venv/bin/pytest -q
	cd ../recycling-web && npm run build
	cd ../recycling-mobile && npm test && npm run build
