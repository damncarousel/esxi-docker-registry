ESXI-DOCKER-REGISTRY_VAR_FILES= \
	-var-file=.provider.tfvars \
	-var-file=.variables.tfvars

# phobos is short for make tf:apply
#
# NOTE this allows you to call `make esxi-docker-registry` from the parent directory
#
esxi-docker-registry:
	@$(MAKE) -s tf:apply!
.PHONY:esxi-docker-registry

_init:
.PHONY: _init

_reset:
.PHONY: _reset

# FIXME/TODO how do we override tf:plan in the root. other tf:plan's are
# namespaced by the directory, eg. foo/tf:plan and overriding foo/tf:plan and
# has no name collisions, in the root, tf:plan itself would have to be the
# target to override and we already have a tf:plan in the .tf.makefile
