.PHONY: ssh
ssh:
	@docker compose exec -u www-data app bash

.PHONY: rssh
rssh:
	@docker compose exec app bash

.PHONY: fe-ssh
fe-ssh:
	@docker compose exec fe sh

.PHONY: docker-build
docker-build:
	@docker compose build

.PHONY: docker-start
docker-start:
	@docker compose up -d

.PHONY: docker-stop
docker-stop:
	@docker compose down

.PHONY: docker-refresh
docker-refresh:
	@docker compose up --build --force-recreate --no-start
