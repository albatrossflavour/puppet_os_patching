#!/bin/sh

# Puppet Task Name: 
#
# This is where you put the shell code for your task.
#
# You can write Puppet tasks in any language you want and it's easy to 
# adapt an existing Python, PowerShell, Ruby, etc. script. Learn more at:
# http://puppet.com/docs/bolt/latest/converting_scripts_to_tasks.html 
# 
# Puppet tasks make it easy for you to enable others to use your script. Tasks 
# describe what it does, explains parameters and which are required or optional, 
# as well as validates parameter type. For examples, if parameter "instances" 
# must be an integer and the optional "datacenter" parameter must be one of 
# portland, sydney, belfast or singapore then the .json file 
# would include:
#   "parameters": {
#     "instances": {
#       "description": "Number of instances to create",
#       "type": "Integer"
#     }, 
#     "datacenter": {
#       "description": "Datacenter where instances will be created",
#       "type": "Enum[portland, sydney, belfast, singapore]"
#     }
#   }
# Learn more at: https://puppet.com/docs/bolt/latest/task_metadata.html
#
YUM=/bin/yum

if [ ! -f $YUM -a ! -f '/etc/redhat-release' ]
then
  RETURN="Not a Redhat system, exiting"
  exit 0
else
  $YUM --security check-update 2>/dev/null 1>/dev/null

  case $? in
    0)   RETURN="No updates available" ;;
    100) RETURN="Updates available"    ;;
    *)   RETURN="Unknown state"        ;;
  esac
fi

JSON="{ \"message\": \"$RETURN\" }"
echo $JSON
exit 0