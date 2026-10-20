.DEFAULT_GOAL := help

.PHONY: help provision build up down update
help:
	@echo 'Targets: provision build up down update'

provision build up down update:
	@bash scripts/host.sh $@
