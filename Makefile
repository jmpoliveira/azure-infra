# Bicep for the shared Azure resources. Needs the Azure CLI (`az`) logged in: `az login`.
# Usage: make what-if RG=<resource-group>      (always before deploy)
#        make deploy  RG=<resource-group> CONFIRM=yes

PARAMS ?= env/dev.bicepparam
TEMPLATE := infra/main.bicep
BICEP_VERSION := v0.49.2

.PHONY: help bicep build lint check whoami require-rg what-if deploy

help:
	@echo "build    compile the templates and the parameters file"
	@echo "lint     run the Bicep linter (rules in bicepconfig.json)"
	@echo "check    build + lint (what CI runs)"
	@echo "what-if  preview the changes in RG (no changes made)"
	@echo "deploy   apply the changes in RG (needs CONFIRM=yes)"

bicep:
	az bicep install --version $(BICEP_VERSION)

build:
	az bicep build --file $(TEMPLATE) --stdout > /dev/null
	az bicep build-params --file $(PARAMS) --stdout > /dev/null

lint:
	az bicep lint --file $(TEMPLATE)
	@for f in infra/modules/*.bicep; do az bicep lint --file $$f || exit 1; done

check: build lint

whoami:
	@az account show --query "{subscription:name, user:user.name}" -o table

require-rg:
	@test -n "$(RG)" || (echo "Set RG=<resource-group>"; exit 2)

# The developer's object id feeds the role assignments without being committed.
what-if: require-rg
	DEVELOPER_PRINCIPAL_ID=$$(az ad signed-in-user show --query id -o tsv) \
	az deployment group what-if --resource-group $(RG) --parameters $(PARAMS)

deploy: require-rg
	@test "$(CONFIRM)" = "yes" || (echo "Run make what-if first, then make deploy CONFIRM=yes"; exit 2)
	DEVELOPER_PRINCIPAL_ID=$$(az ad signed-in-user show --query id -o tsv) \
	az deployment group create --resource-group $(RG) --parameters $(PARAMS) \
	  --name "azure-infra-$$(date +%Y%m%d-%H%M%S)"
