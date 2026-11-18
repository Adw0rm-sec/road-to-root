# Road to Root — range control
# Thin wrapper around docker compose so you don't have to remember flags.

.DEFAULT_GOAL := help
COMPOSE := docker compose

.PHONY: help up up-cron up-sudo up-path up-web up-caps up-wild up-pivot up-docker down attacker \
        shell-suid shell-cron shell-sudo shell-path shell-web shell-caps shell-wild shell-pivot shell-docker \
        reset-suid reset-cron reset-sudo reset-path reset-web reset-caps reset-wild reset-pivot reset-docker \
        logs-suid logs-cron logs-sudo logs-path logs-web logs-caps logs-wild logs-pivot logs-docker \
        test-suid test-cron test-sudo test-path test-web test-caps test-wild test-pivot test-docker \
        ps clean

help:            ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

up:              ## Build + start the attacker and the SUID target
	$(COMPOSE) up -d --build attacker target-suid

up-cron:         ## Build + start the attacker and the cron target
	$(COMPOSE) up -d --build attacker target-cron

up-sudo:         ## Build + start the attacker and the sudo target
	$(COMPOSE) up -d --build attacker target-sudo

up-path:         ## Build + start the attacker and the PATH target
	$(COMPOSE) up -d --build attacker target-path

up-web:          ## Build + start the attacker and the web target (Ch 09)
	$(COMPOSE) up -d --build attacker target-web
	@echo "Hollow Share is live at http://127.0.0.1:8080/  (point Burp here)"

up-caps:         ## Build + start the attacker and the capabilities target (Ch 05)
	$(COMPOSE) up -d --build attacker target-caps

up-wild:         ## Build + start the attacker and the wildcard target (Ch 06)
	$(COMPOSE) up -d --build attacker target-wild

up-pivot:        ## Build + start the attacker and the pivot target (Ch 07)
	$(COMPOSE) up -d --build attacker target-pivot

up-docker:       ## Build + start the attacker and the docker-socket target (Ch 08)
	$(COMPOSE) up -d --build attacker target-docker

down:            ## Stop and remove the whole range
	$(COMPOSE) down

attacker:        ## Drop into a shell on the attacker box
	docker exec -it attacker bash

shell-suid:      ## Root shell on the SUID target (for inspecting/resetting)
	docker exec -it target-suid bash

shell-cron:      ## Root shell on the cron target (for inspecting/resetting)
	docker exec -it target-cron bash

shell-sudo:      ## Root shell on the sudo target (for inspecting/resetting)
	docker exec -it target-sudo bash

shell-path:      ## Root shell on the PATH target (for inspecting/resetting)
	docker exec -it target-path bash

shell-web:       ## Root shell on the web target (for inspecting/resetting)
	docker exec -it target-web bash

shell-caps:      ## Root shell on the capabilities target (for inspecting/resetting)
	docker exec -it target-caps bash

shell-wild:      ## Root shell on the wildcard target (for inspecting/resetting)
	docker exec -it target-wild bash

shell-pivot:     ## Root shell on the pivot target (for inspecting/resetting)
	docker exec -it target-pivot bash

shell-docker:    ## Root shell on the docker-socket target (for inspecting/resetting)
	docker exec -it target-docker bash

reset-suid:      ## Rebuild the SUID target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-suid

reset-cron:      ## Rebuild the cron target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-cron

reset-sudo:      ## Rebuild the sudo target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-sudo

reset-path:      ## Rebuild the PATH target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-path

reset-web:       ## Rebuild the web target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-web

reset-caps:      ## Rebuild the capabilities target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-caps

reset-wild:      ## Rebuild the wildcard target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-wild

reset-pivot:     ## Rebuild the pivot target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-pivot

reset-docker:    ## Rebuild the docker-socket target back to pristine-vulnerable
	$(COMPOSE) up -d --build --force-recreate target-docker

logs-suid:       ## Tail auth logs from the SUID target
	docker logs -f target-suid

logs-cron:       ## Tail auth logs from the cron target
	docker logs -f target-cron

logs-sudo:       ## Tail auth logs from the sudo target
	docker logs -f target-sudo

logs-path:       ## Tail auth logs from the PATH target
	docker logs -f target-path

logs-web:        ## Tail Apache logs from the web target
	docker logs -f target-web

logs-caps:       ## Tail logs from the capabilities target
	docker logs -f target-caps

logs-wild:       ## Tail logs from the wildcard target
	docker logs -f target-wild

logs-pivot:      ## Tail logs from the pivot target
	docker logs -f target-pivot

logs-docker:     ## Tail logs from the docker-socket target
	docker logs -f target-docker

test-suid:       ## Run the self-test for the SUID lab inside the container
	docker cp tests/verify_suid.sh target-suid:/tmp/verify_suid.sh
	docker exec target-suid chmod 755 /tmp/verify_suid.sh
	docker exec -u labuser1 target-suid bash /tmp/verify_suid.sh

test-cron:       ## Run the self-test for the cron lab inside the container (~2 min)
	docker cp tests/verify_cron.sh target-cron:/tmp/verify_cron.sh
	docker exec target-cron chmod 755 /tmp/verify_cron.sh
	docker exec -u labuser1 target-cron bash /tmp/verify_cron.sh

test-sudo:       ## Run the self-test for the sudo lab inside the container
	docker cp tests/verify_sudo.sh target-sudo:/tmp/verify_sudo.sh
	docker exec target-sudo chmod 755 /tmp/verify_sudo.sh
	docker exec -u labuser1 target-sudo bash /tmp/verify_sudo.sh

test-path:       ## Run the self-test for the PATH lab inside the container
	docker cp tests/verify_path.sh target-path:/tmp/verify_path.sh
	docker exec target-path chmod 755 /tmp/verify_path.sh
	docker exec -u labuser1 target-path bash /tmp/verify_path.sh

test-web:        ## Exploit all six web routes + reverse shell from the attacker
	docker cp tests/verify_web.sh attacker:/tmp/verify_web.sh
	docker exec attacker chmod 755 /tmp/verify_web.sh
	docker exec attacker bash /tmp/verify_web.sh target-web

test-caps:       ## Run the self-test for the capabilities lab inside the container
	docker cp tests/verify_caps.sh target-caps:/tmp/verify_caps.sh
	docker exec target-caps chmod 755 /tmp/verify_caps.sh
	docker exec -u labuser1 target-caps bash /tmp/verify_caps.sh

test-wild:       ## Run the self-test for the wildcard lab inside the container (~2 min)
	docker cp tests/verify_wild.sh target-wild:/tmp/verify_wild.sh
	docker exec target-wild chmod 755 /tmp/verify_wild.sh
	docker exec -u labuser1 target-wild bash /tmp/verify_wild.sh

test-pivot:      ## Exploit both port-forward paths from the attacker (~2 min)
	docker cp tests/verify_pivot.sh attacker:/tmp/verify_pivot.sh
	docker exec attacker chmod 755 /tmp/verify_pivot.sh
	docker exec attacker bash /tmp/verify_pivot.sh target-pivot

test-docker:     ## Run the self-test for the docker-socket lab inside the container
	docker cp tests/verify_docker.sh target-docker:/tmp/verify_docker.sh
	docker exec target-docker chmod 755 /tmp/verify_docker.sh
	docker exec -u labuser1 target-docker bash /tmp/verify_docker.sh

ps:              ## Show range status
	$(COMPOSE) ps

clean:           ## Tear down + remove built images
	$(COMPOSE) down --rmi local
