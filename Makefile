# Road to Root — range control
# Thin wrapper around docker compose so you don't have to remember flags.

.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help up up-cron down attacker \
        shell-suid shell-cron reset-suid reset-cron logs-suid logs-cron \
        test-suid test-cron ps clean

help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up:              ## Build + start the attacker and the SUID target
	$(COMPOSE) up -d --build attacker target-suid

up-cron:         ## Build + start the attacker and the cron target
	$(COMPOSE) up -d --build attacker target-cron

down:            ## Stop and remove the whole range
	$(COMPOSE) down

attacker:        ## Drop into a shell on the attacker box
	docker exec -it attacker bash

shell-suid:      ## Root shell on the SUID target (for inspecting/resetting)
	docker exec -it target-suid bash

shell-cron:      ## Root shell on the cron target (for inspecting/resetting)
	docker exec -it target-cron bash

reset-suid:      ## Rebuild the SUID target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-suid

reset-cron:      ## Rebuild the cron target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-cron

logs-suid:       ## Tail auth logs from the SUID target
	docker logs -f target-suid

logs-cron:       ## Tail auth logs from the cron target
	docker logs -f target-cron

test-suid:       ## Run the self-test for the SUID lab inside the container
	docker cp tests/verify_suid.sh target-suid:/tmp/verify_suid.sh
	docker exec target-suid chmod 755 /tmp/verify_suid.sh
	docker exec -u labuser1 target-suid bash /tmp/verify_suid.sh

test-cron:       ## Run the self-test for the cron lab inside the container (~2 min)
	docker cp tests/verify_cron.sh target-cron:/tmp/verify_cron.sh
	docker exec target-cron chmod 755 /tmp/verify_cron.sh
	docker exec -u labuser1 target-cron bash /tmp/verify_cron.sh

ps:              ## Show range status
	$(COMPOSE) ps

clean:           ## Tear down + remove built images
	$(COMPOSE) down --rmi local
