# _Path tries to nomalize the path given the module we want (first arg)
# regardless of whether we are outside or in the given module
#
# Example:
#
#	pwd => /path/to/infra
#	$(call _Path,nginx)
#	=> /path/to/infra/nginx
#
#	pwd => /path/to/infra/nginx
#	$(call _Path,nginx)
#	=> /path/to/infra/nginx
#
# This allows us to call our commands with namespaces in the root or within the
# module itself.
#
# NOTE this generall assumes that your terraform module structures are only 1
# directory deep
#
#	/path/to/infra
#		./nginx
#		./app
#
# FIXME will not path properly if the module we actually want is the same name
# as the parent dir we are calling this function from
#
#	/path/to/app
#		./nginx
#		./app
#
#	pwd => /path/to/app
#	$(call _Path,app)
#	=> /path/to/app
#
#	In this case we want /path/to/app/app
#
# As an aside, my echo | sed method probably not the best way to do this...
#
define _Path =
$(shell echo "$$(pwd)/$(1)" | sed -e 's#/$(1)/$(1)$$#/$(1)#ig' | sed -e 's#/\.$$##ig')
endef

# _Basename returns the basename on pwd
define _Basename
$(shell echo "$$(basename $$(pwd))")
endef

# _Varfiles returns the <module>_VAR_FILES= defined in the module's .makefile
# allowing us to predefine our variable file reference and use those when we
# call `terraform plan`
define _Varfiles
$(value $(shell echo "$(call _Basename)_var_files" | tr 'a-z' 'A-Z'))
endef

# _Tfoutput runs a terraform output on a given variable name
#
# NOTE stder > /dev/null
#
define _Tfoutput =
$(shell terraform output $(1) 2>/dev/null)
endef

# Terraform commands
#

# tf:init is terraform init
tf\:init:
	@terraform init
.PHONY: tf\:init

# %/tf:init calls tf:init from the given module
#
#	nginx/tf:init
#
%/tf\:init:
	@$(MAKE) -s -C $(call _Path,$*) tf:init
.PHONY: %/tf\:init

# tf:reset removes the .terraform directory
tf\:reset:
	@rm -rf .terraform
.PHONY: tf\:reset

# %/tf:reset calls tf:reset from the given module
%/tf\:reset:
	@$(MAKE) -s -C $(call _Path,$*) tf:reset
.PHONY: %/tf\:reset

# tf:plan calls terraform plan and outputs as 'plan'
tf\:plan:
	@terraform plan $(call _Varfiles) -out=plan
.PHONY: tf\:plan

# %/tf:plan calls tf:plan from the given module
%/tf\:plan:
	@$(MAKE) -s -C $(call _Path,$*) tf:plan
.PHONY: %/tf\:plan

# tf:clean removes the created 'plan'
tf\:clean:
	@rm -f plan
.PHONY: tf\:clean

# %/tf:clean calls tf:clean from the given module
%/tf\:clean:
	@$(MAKE) -s -C $(call _Path,$*) tf:clean
.PHONY: %/tf\:clean

# tf:apply calls terraform apply on the plan
#
# NOTE if ./plan does not exist it will run tf:plan
#
tf\:apply:
	@if [ ! -f ./plan ]; then \
		$(MAKE) -s tf:plan; \
	fi
	@terraform apply plan
.PHONY: tf\:apply

# %/tf:apply calls tf:apply from the given module
%/tf\:apply:
	@if [ ! -f "$*/plan" ]; then \
		$(MAKE) -s $*/tf:plan; \
	fi
	@$(MAKE) -s -C $(call _Path,$*) tf:apply
.PHONY: %/tf\:apply

# tf:apply! (note !) calls a tf:clean before tf:apply, this ensures plan is
# always run
tf\:apply!:
	@$(MAKE) -s tf:clean
	@$(MAKE) -s tf:apply
.PHONY: tf\:apply!

# %/tf:apply! calls tf:apply! from the given module
%/tf\:apply!:
	@$(MAKE) -s $*/tf:clean
	@$(MAKE) -s $*/tf:apply
.PHONY: %/tf\:apply!

# tf:__destroy__ calls terraform destroy
#
# NOTE the reason we name it this way is because we want to make calling this a
# PITA as it will destroy your stuff. This makes it "private", sort of...
#
# Also if you want to force confirmation of a destroy for a large teardown
# process of a number of terraform modules, you have to directly use this.
#
#	echo Yes | make tf:__destroy__
#
tf\:__destroy__:
	@terraform destroy $(call _Varfiles)
.PHONY: tf\:__destroy__

# %/tf:__destroy__ calls tf:__destroy__ from the given module
%/tf\:__destroy__:
	@$(MAKE) -s -C $(call _Path,$*) tf:__destroy__
.PHONY: %/tf\:__destroy__

# tf:destroy calls the tf:__destroy__ but must be confirmed by a key. The key
# is generated automatically on each call
#
# Thank you! https://gist.github.com/earthgecko/3089509
#
# NOTE original $(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
# Does not work on Mac OS throws `tr: Illegal byte sequence`
# https://unix.stackexchange.com/questions/45404/why-cant-tr-read-from-dev-urandom-on-osx/217276
#
tf\:destroy:
	@$(eval NAME=$(call _Basename))
	@key=$$(LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1); \
		echo "To destroy '$(NAME)', you must verify your key."; \
		echo "Your current key is: $$key\n"; \
		read -p "Verify: " __key; \
		if [ "$$key" != "$$__key" ]; then \
			echo; \
			echo "The key you provided was invalid"; \
			echo; \
			exit 1; \
		fi
	@echo
	@$(MAKE) -s tf:__destroy__
.PHONY: tf\:destroy

# %/tf:destroy calls tf:destroy from the given module
%/tf\:destroy:
	@$(MAKE) -s -C $(call _Path,$*) tf:destroy
.PHONY: %/tf\:destroy


# Bootstrapping commands
#

# NOTE if the working dir has an overridden init:<dir> (or reset:) command,
# callbacks will not be called.

# init:root copies over the necessary tfvars from the template dir
init\:root:
	@$(MAKE) -s cp:.tfvars
	@$(MAKE) -s tf:init
.PHONY: init\:root

# init:% runs a couple of basic commands to get your module ready
#
# NOTE the _init callback is called before tf:init
#
# NOTE this calls tf:init, but depending on if you actually confirgured your
# variables tf:init will fail. `terraform init` will fail without all the
# working pieces.
#
init\:%:
	@$(MAKE) -s $*/ln:provider.tf
	@$(MAKE) -s $*/cp:.tfvars
	@$(MAKE) -s $*/_init
	@$(MAKE) -s $*/tf:init
.PHNONY: init\:%

# %/_init calls _init in the modules's .makefile allowing you to provide a
# module specific callback as part of the init
%/_init:
	@$(MAKE) -s -C $(call _Path,$*) _init || true
.PHONY: %/_init

# reinit:% just calls init:% but removes the copied .tfvars
#
# NOTE this would be generally called as you plan your module directory and
# need to link or relink updated tfvars files
#
reinit\:%:
	@$(MAKE) -s $*/rm:.tfvars
	@$(MAKE) -s init:$*
.PHONY: reinit\:%

# reset:% tearsdown anything setup in init:%
#
# NOTE reset does not remove generated SSH keys in .ssh/, those have to be
# deleted manually
#
reset\:%:
	@$(MAKE) -s $*/tf:reset
	@$(MAKE) -s $*/rm:provider.tf
	@$(MAKE) -s $*/rm:.tfvars
	@$(MAKE) -s $*/_reset
.PHONY: reset\:%

# %/_reset calls _reset in the modules's .makefile allowing you to provide a
# module specific callback as part of the reset
%/_reset:
	@$(MAKE) -s -C $(call _Path,$*) _reset || true
.PHONY: %/_reset

# ln:provider.tf symlinks the parent's provider file to the current dir
#
# NOTE this will remove the existing provider file before creating a new link
#
ln\:provider.tf:
	@$(MAKE) -s rm:provider.tf
	@ln -s ../provider.tf ./provider.tf
.PHONY: ln\:provider.tf

# %/ln:provider.tf calls ln\:provider.tf from the given module
%/ln\:provider.tf:
	@$(MAKE) -s -C $(call _Path,$*) ln:provider.tf
.PHONY: %/ln\:provider.tf

# rm:provider.tf remove the provider file
rm\:provider.tf:
	@rm -f ./provider.tf
.PHONY:rm\:provider.tf

# %/rm:provider.tf calls rm:provider.tf from the given module
%/rm\:provider.tf:
	@$(MAKE) -s -C $(call _Path,$*) rm:provider.tf
.PHONY:%/rm\:provider.tf

# cp:.tfvars copies the tfvars file from .templates
#
# NOTE this does not overwrite an existing variables tfvars files
#
# TODO this should also update the <DIR>_VAR_FILES= for any new tfvars
#
cp\:.tfvars:
	@for file in ./.templates/*.tfvars; do \
		cp -n "$$file" .$$(basename "$$file"); \
	done
.PHONY: cp\:.tfvars

# %/cp:.tfvars calls cp:.tfvars from the given module
%/cp\:.tfvars:
	$(MAKE) -s -C $(call _Path,$*) cp:.tfvars
.PHONY: %/cp\:.tfvars

# rm\:.tfvars removes the tfvars files
#
# NOTE this will remove all your .*.tfvars files, not only those cp'd during
# `make cp:.tfvars`
#
rm\:.tfvars:
	@rm -f .*.tfvars
.PHONY: rm\:.tfvars

# %/rm:.tfvars: calls rm:.tfvars from the given module
%/rm\:.tfvars:
	@$(MAKE) -s -C $(call _Path,$*) rm:.tfvars
.PHONY: %/rm\:.tfvars


# SSH commands
#

# hasSshDir checks for an .ssh directory
hasSshDir:
	@if [ ! -d .ssh ]; then \
		echo "$(call _Basename) ($$(pwd)) does not contain an .ssh folder"; \
		echo "To support SSH please create an .ssh folder in $$(pwd)"; \
		echo; \
		exit 1; \
	fi
.PHONY: hasSshDir

# mkdir:.ssh creates a .ssh directory
mkdir\:.ssh:
	@mkdir -p .ssh
.PHONY: mkdir\:.ssh

# %/mkdir:.ssh calls mkdir:.ssh from the given module
%/mkdir\:.ssh:
	@$(MAKE) -s -C $(call _Path,$*) mkdir:.ssh
.PHONY: %/mkdir\:.ssh

# ssh-keygen helps generate an ssh key
#
# NOTE you must a .ssh directory to designate that the current module supports
# or needs ssh keys
#
ssh-keygen:
	@$(MAKE) -s hasSshDir
	@ssh-keygen -t rsa -b 4096 -f "$$(pwd)/.ssh/id_rsa"
	@sudo chmod -R 600 $$(pwd)/.ssh/*
.PHONY: ssh-keygen

# %/ssh-keygen calls ssh-keygen from the given module
%/ssh-keygen:
	@$(MAKE) --no-print-directory -C $(call _Path,$*) ssh-keygen
.PHONY: %/ssh-keygen

# rm:.ssh removes the contents of the .ssh folder
rm\:.ssh:
	@$(MAKE) -s hasSshDir
	@rm -f .ssh/*
.PHONY: rm\:.ssh

# %/rm:.ssh calls rm:.ssh from the given module
%/rm\:.ssh:
	@$(MAKE) --no-print-directory -C $(call _Path,$*) rm:.ssh
.PHONY: %/rm\:.ssh

# tf:output:% runs terraform output on the given variable name
#
# NOTE this is generally for debugging and not readily used
#
tf\:output\:%:
	@echo $(call _Tfoutput,$*)
.PHONY: tf\:output\:%

# ssh launches an ssh session using the .ssh/id_rsa generated from
# `make ssh-keygen`
#
ssh:
	@$(MAKE) -s hasSshDir
	@$(eval IP=$(call _Tfoutput,'ipv4_address'))
	@$(eval NAME=$(call _Basename))
	@echo "SSH $(NAME) -\n"
	@echo "What is the IP[V4] address of the $(NAME) instance?"
	@if [ -z "$(IP)" ]; then \
		read -p "IP[V4]: " ip; \
		ip="$$ip" $(MAKE) -s _ssh; \
	else \
		echo "'ipv4_address' output found, using: $(IP)"; \
		ip="$(IP)" $(MAKE) -s _ssh; \
	fi
.PHONY: ssh

# _ssh is an extension of ssh, this is not called directly, because of our read
# -p scoping
_ssh:
	@echo; \
		echo "Who do you want to SSH in as?"; \
		read -p "Username: " username; \
		echo; \
		echo "Thank you... one moment as we SSH $$username@$$ip"; \
		echo; \
		ssh -i "$$(pwd)/.ssh/id_rsa" $$username@$$ip
.PHONY: _ssh

# ssh:% calls ssh for the given module
ssh\:%:
	@$(MAKE) -s -C $(call _Path,$*) ssh
.PHONY: ssh\:%


# Terraform directory creation
#
# NOTE these commands below should only be called from the parent directory
#

# tf:mkdir generates a module directory with some basic bootstrapping and
# linking of makefiles, as well as writing in some basic short hands to longer
# commands listed above
#
# NOTE this will reset any Makefiles or .makefiles already in your directory,
# so beware to run this twice after an initial call and configuration
#
# It craetes a module directory as such
#
#	module/
#		.makefile
#		.templates/
#			variables.tfvars
#		Makefile
#		variables.tf
#
# FIXME use $(eval) where applicable
# TODO add the root .variables.tfvars files as part of the <module>_VAR_FILES=
tf\:mkdir:
	@$(eval NAME=$(call _Basename))
	@echo -n "bootstrapping $(call _Basename)..."
	@mkdir -p .templates
	@touch .makefile Makefile \
		.templates/variables.tfvars variables.tf
	@_var_files=$(shell echo "$(call _Basename)_var_files" | tr 'a-z' 'A-Z'); \
		echo "$$_var_files= \\" > .makefile
	@echo "\t-var-file=../.provider.tfvars \\" >> .makefile
	@echo "\t-var-file=.variables.tfvars" >> .makefile
	@echo "" >> .makefile
	@_name=$$(echo "$(call _Basename)"); \
		echo "# $$_name is short for make $$_name/tf:apply\n#" >> .makefile; \
		echo "# NOTE this allows you to call \`make $$_name\` from the parent directory\n#" >> .makefile; \
		echo "$$_name:\n\t@\$$(MAKE) -s \$$@/tf:apply!\n.PHONY: $$_name" >> .makefile
	@echo "" >> .makefile
	@echo "_init:\n.PHONY: _init\n" >> .makefile
	@echo "_reset:\n.PHONY: _reset\n" >> .makefile
	@echo "" > Makefile
	@for t in plan apply apply! destroy; do \
		echo "$$t:\n\t@\$$(MAKE) -s $(NAME)/tf:\$$@\n.PHONY: $$t\n" >> Makefile; \
	done
	@echo "" >> Makefile
	@for t in init reset; do \
		_name=$$(echo "$(call _Basename)"); \
		echo "$$t:\n\t@\$$(MAKE) -s \$$@:$$_name\n.PHONY: $$t\n" >> Makefile; \
	done
	@echo "" >> Makefile
	@echo "include .makefile" >> Makefile
	@echo "include ../.makefile" >> Makefile
	@echo "" >> Makefile
	@if ! grep -q 'include\s*\$(call _Basename)/\.makefile' ../Makefile; then \
		sed -i -e "/include\s*\.makefile/{iinclude $(call _Basename)/.makefile" -e ':a;n;ba}' ../Makefile; \
	fi
	@echo " complete"
.PHONY: tf\:mkdir

# tf:mkdir:% calls tf:mkdir for the given module name
tf\:mkdir\:%:
	@mkdir -p $*
	@cd $(call _Path,$*); make -s -f ../.makefile tf:mkdir
.PHONY: tf\:mkdir\:%

# tf:root bootstraps the root/parent directory
tf\:root:
	@echo -n "Bootstrapping your terraform root directory..."
	@mkdir -p .templates
	@touch .templates/variables.tfvars .templates/provider.tfvars
	@touch provider.tf variables.tf
	@touch Makefile
	@if grep -q 'include\s*\.tf.makefile' Makefile; then \
		sed -i -e "s#.*include\s*\.tf.makefile.*#include .tf.makefile#g" Makefile; \
	else \
		echo "include .tf.makefile\n" >> Makefile; \
	fi
	@echo " complete"
.PHONY: tf\:root



# mkdir:% is a shortcut target for `mkdir -p`
mkdir\:%:
	@mkdir -p $*
.PHONY: mkdir\:%
