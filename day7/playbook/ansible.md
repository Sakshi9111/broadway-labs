#################
# Run inventory #
#################

ansible-playbook -i inventory.ini demo.yml

#########################
#  path to private key  #
#########################
ansible web -i inventory.ini -u ubuntu   --private-key path_to_pem   -m ansible.builtin.ping


##########################
# Debug Commands         #
##########################
Purpose

	

### Commands

Run a playbook --> ansible-playbook -i inventory.ini playbook.yml

Run with verbose output --> ansible-playbook -i inventory.ini playbook.yml -v

Run in check mode (dry run) --> ansible-playbook -i inventory.ini playbook.yml --check

Run only tagged tasks --> ansible-playbook -i inventory.ini playbook.yml --tags setup

Run a specific task by name --> ansible-playbook -i inventory.ini playbook.yml --start-at-task="Task name"

Check playbook syntax   -->  ansible-playbook -i inventory.ini playbook.yml --syntax-check