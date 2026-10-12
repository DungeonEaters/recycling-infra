.PHONY: up down logs test reset web mobile dev-api dev-web dev-mobile test-local oci-test-status oci-test-resources deploy-test-check deploy-test-api deploy-test-web

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

oci-test-status:
	./scripts/inspect-oci-test.sh

oci-test-resources:
	./scripts/inspect-oci-test-resources.sh

deploy-test-check:
	./scripts/deploy-test-api.sh --check

deploy-test-api:
	@test -n "$(IMAGE_TAG)" || (echo "Set IMAGE_TAG to an existing backend GHCR tag." >&2; exit 2)
	./scripts/deploy-test-api.sh --image-tag "$(IMAGE_TAG)"

deploy-test-web:
	./scripts/deploy-test-web.sh
