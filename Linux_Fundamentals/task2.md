# Linux Fundamentals 

## Difference between useradd and adduser command 

useradd- useradd is a native, low- level binary compiled executable, that lets one create raw user profile. It requires -m flag to be created, it is not 
created automatically. Password mut be set manually using the passwd command. useradd is Universal in Linux and can be used under any Distribution. 

adduser- adduser is a high- level iteractive script (usually Perl or Bash ), that lets you create a user profile in guided steps. It does not require a flag and 
can be create through interactive TUI interface. It prompts you create a password during setup. adduser is dependent on the Distribution you use, for example, it is 
available on Debain, Ubuntu, but it is missing or only symlink to useradd on Distributions like Red Hat, Fedora. 

Which command is preferred in Ubuntu Linux Distribution and why? 

adduser command is preferred for Ubuntu Linux because it is user- friendly, and creates a user profile with guided instructions without any flags required with 
sudo adduser username 
It creates a profile automatically with home directory, copies skeleton config files (like .bashrc ), sets /bin/bash as default shell, and prompts you to set a 
password for the profile. adduser also respects system wide configuration files located at /etc/adduser.conf. This ensures that every human user created conforms to the 
exact same folder structure, UID/ GID, ranges and permissions. 
If you are writing automation scripts or using configuration management tools like Ansible or Puppet, then you should use useradd because it creates a profile directory 
with no home directory, password, and with a restricted shell like ./bin/sh, because of its non- interactive nature it will ensure that it does not pause for human- input. 

![Task 2 1 ](Linux_2a.png ) 
![Task 2 2 ](Linux_2b.png ) 

