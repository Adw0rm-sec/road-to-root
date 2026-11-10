# Road to Root — range control
# Thin wrapper around docker compose so you don't have to remember flags.

.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help up down attacker reset-suid logs-suid shell-suid ps clean

help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up:              ## Build + start the attacker and the SUID target
	$(COMPOSE) up -d --build attacker target-suid

down:            ## Stop and remove the whole range
	$(COMPOSE) down

attacker:        ## Drop into a shell on the attacker box
	docker exec -it attacker bash

shell-suid:      ## Root shell on the SUID target (for inspecting/resetting)
	docker exec -it target-suid bash

reset-suid:      ## Rebuild the SUID target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-suid

logs-suid:       ## Tail auth logs from the SUID target
	docker logs -f target-suid

ps:              ## Show range status
	$(COMPOSE) ps

clean:           ## Tear down + remove built images
	$(COMPOSE) down --rmi local
