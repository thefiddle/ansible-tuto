VAGRANT AND ANSIBLE : TUTO FOR WINDOWS DEPLOYEMENT 
==================================================
***
## INTRODUCTION  

In this tutorial, we will learn how to use two very useful tools :

1. **vagrant** for vm managing easily on a desktop pc 
2. **ansible** for deploying stuff on a Windows server

This will be achieved with the simple architecture 
 


***

## VAGRANT 

In this part, we will create the vms that will be used to run ansible. These vm will be created by **vagrant**, which will
manage the vm provider **virtualbox**.

For windows host, you can get these tools there :

- [virtualbox](http://download.virtualbox.org/virtualbox/5.1.14/VirtualBox-5.1.14-112924-Win.exe)
- [vagrant](https://releases.hashicorp.com/vagrant/1.9.1/vagrant_1.9.1.msi)

For linux hosts : 
```
apt-get install virtualbox vagrant
```

The next steps are easy : 

1. Fetch the **vagrant box** used as a base system image
2. Edit the **Vagrantfile** to configure our vm
3. Make provisionning on the VMs to get everything ready to use ansible
4. Use **vagrant** to start/stop  the vm
5. Use **vagrant** to connect to the guests with a note about credentials
 
### 1/ Fetch the vagrant box

Vagrant uses box to create guests VM. These boxes are like os ISO wrappers for virtual machines providers that vagrant can use to create VMs.
These box contains installed systems images with basic needs to communicate with vm provider. They also provide a public free catalog of boxes
in which you can find a lot of systems.

[Box Catalog](https://atlas.hashicorp.com/boxes/search).

For this tutorial we need two box : the windows box "opentable/win-2012r2-standard-amd64-nocm" and the ubuntu box "ubuntu/trusty64".
To download the box:

```
vagrant box add opentable/win-2012r2-standard-amd64-nocm --provider virtualbox
vagrant box add ubuntu/trusty64 --provider virtualbox
```

### 2/ Edit the VagrantFile 

The ***Vagrantfile*** is where we will configure the vms that vagrant will create calling the provider. In this file, 
we will configure:
 
- Box used for our vm
- Resources cpu / memory of the vm
- Network rules for the guests
- Sync folder between host and guest
- VM provider customization [options for virtualbox](https://www.virtualbox.org/manual/ch08.html#vboxmanage-modifyvm)
- Provisionning for preparing the machine


When initiating a project, we can create a ***Vagrantfile*** for a single VM managing with the command :
```
vagrant init  opentable/win-2012r2-standard-amd64-nocm
```
This will only create the  ***Vagrantfile*** and ensure ***opentable/win-2012r2-standard-amd64-nocm*** box is present.
For this tuto, we will use the Vagrantfile provided that contains defintions for all of our vms. 

Network config:
Guests should get a private network with host, that MUST NOT be in the same subnet as the hosts subnet. It also allow
have a static IP for the vm.


```
VBoxManage list bridgedifs
```

### 3/ Provison the guests : 

The vagrant provisionner runs on both machines after creation of the wm or when explicit calling **vagrant provision**
command. The scripts bash and powershell provided in provision directory will automatically do the steps for you. To sum up : 

- For linux ansible guest, the only thing to do is install ansible and the pywinrm python module, used by ansible to 
communicate with the windows guest. This is done in the provisionning script [provision/ansible-master.sh](provision/ansible-master.sh)
    
- For windows guest, we will enable remote powershell using  [provision/ConfigureRemotingForAnsible.ps1](provision/ConfigureRemotingForAnsible.ps1) script that 
you can find on Ansible Windows documentation. The previous script [provision/setup_windows_guest.ps1](provision/setup_windows_guest.ps1]) used in 
Vagrantfile is used to set up french Language on systems, so we will have our azerty set up when doing rdp


### 4/ Start - stop the vms

Once done, you will be able to create guest using the Vagrantfile.
```
vagrant up ansible-master
vagrant up windows-guest
```
This will create and run the vm if not created, only start if created and stopped 

To stop a vm : 
```
vagrant halt ansible-master
vagrant halt windows-guest
```

To restart a vm, with provisionning at start line 2 : 
```
vagrant reload ansible-master
vagrant reload --provision windows-guest
```


To destroy the vm : 
```
vagrant destroy ansible-master
vagrant destroy windows-guest
```

Provision scripts runs when vagrant up is called if the vm is not already created. If you want to run the provisionner only,
you can always call : 

```
vagrant provision ansible-master
vagrant provision windows-guest
```

### 5/ Connect to guests:

#### Credentials

In many cases, vagrant boxes are made with two accounts, an administrator and a normal user account with the **vagrant** password.
Exemple :   

- Admin Windows box : ***Administrator*** / ***vagrant*** 
- Admin linux box   : ***root*** / ***vagrant***
- Normal user		: ***vagrant*** / ***vagrant*** 

For linux host, the auth is made with an auth key (stored in your host user_home_dir/.vagrant.d/). For windows host, 
***config.winrm.username*** and ***config.winrm.password***




#### Connection to linux ansible-master 

The connection to ansible-master linux host is made through ssh. If your host is a linux, no problem native ssh
 will handle the ssh connection. 
For windows hosts, the simplest way to bring the ssh command is to install git executable and be sure to select 
"Use Git and optional Unix tools from the windows Command Prompt" see [https://git-scm.com/download/win](https://git-scm.com/download/win). This will 
bring ssh command line executable to your windows hosts

The command to connect ssh to your ansible-master node is:
```
vagrant ssh ansible-master
```
  
##### Connection to windows-guest 

Note : one common problem that happens when starting automating anything is to use "non-interactive" commands.
If a deploy script contains a confirmation to run, it will just hang indefinitely when executing by the autmated system.
RDP Connection can ask for SSL confirmation before going on. This justify the next command that allows us to run 
an rdp connection from command line (extra parameter should be tested and maybe changed on windows hosts)

Windows hosts will be able to connect easily using native rdp client mstsc. The drawback is that mstsc executable 
cannot get user/password from command line and has no options to skip ssl verification. 

```
vagrant rdp windows-guest 
```

For Linux hosts, the simplest way to bring a rdp client like freerdp.
```
sudo apt-get install freerdp
```

Ex with freerdp from linux host ( -- allows you to add args to freerdp program)  
```
vagrant rdp windows-guest  -- /cert-ignore
```

 ***
 
## ANSIBLE

Every commands executed here will be run from the ansible-master host 


### Bare concepts 

[Tres bon article pour debuter avec ansible et windows](https://www.it-connect.fr/debutez-avec-ansible-et-gerez-vos-serveurs-windows/)
[Very good summary](http://people.ds.cam.ac.uk/jw35/docs/ansible/ansible-summary.html)

Our vms are ready, we now have to dig into Ansible:

- Ansible can connect to nodes to perform tasks on them
- The nodes are refered in an inventory (ini file like) where there dns/IP are sorted into groups.
- It can do it using two modes : adhoc (single command performed on a set of nodes) and playbook (playbook recipe applied)
- Task can be copying files, setting soft or system functionnalites, start/ensure service running, templating files with variables
- To define a task work, we call a module with args. When calling modules, we can get also some facts about the execution 
 and get a return value, an exception test 
- Variables can be set are several different level to avoid redundancy defintions
- Playbooks are used to organize tasks and variables, roles is an other level of file organization


### Ansible directory typical file architecture 

Everything could be written in one big file, but ansible provides playbooks and include to get a clearer and handy file 
architecture.

[See best pratices](http://docs.ansible.com/ansible/playbooks_best_practices.html#best-practices)

``` 
ansible/
       +
       |
       +staging.yml							 # playbook for staging env 
       |
       +production.yml 						 # Playbook for prod env
       |
       |
       +webserver.yml						 # Playbook for deploying a webserver
       |
       |
       +hosts 						  	     # def of hosts and group 
       |
       +group_vars/windows.yml   			 # variables def for windows group
       |            +
       |            +all.yml        		 # variables def for all hosts groups
       |			|
       |			+...
       |
       +host_vars/192.168.130.100.yml    	 # variables def specifique for 192.168.130.100 host 
       |           |
       |           +...
       |
       |
       +roles/common/tasks/					 # List of tasks definition files
       |	 |	  	| 	  	|
       |	 |	  	|	  	+main.yml
       |	 |	  	|
       |	 |	  	/vars/					# List of vars automatically loaded when playing this role
       |	 |	  	| 	  	|
       |	 |	  	|	  	+main.yml
       |	 |	  	| 	
       |	 |	  	/meta/					# Role dependencies 
       |	 |	  	| 	  	|
       |	 |	  	|	  	+main.yml
       |	 |	  	| 	
       |	 |	  	/defaults/				# Role defaults values
       |	 |	  	| 	  	|
       |	 |	  	|	  	+main.yml
       |	 |		|
       |	 |	  	/files/					# Roles files to provide
       |	 |	  	| 	  	
       |	 |	  	|	  	
       |	 |	  	|
       |	 |	  	/templates/				# Roles templated files (typically .j2 files) 
       |	 |	  	| 	  	
       |	 |	  	|	  	
       |	 |	  	|
       |	 |	  	/library/				# Plugin library
       |	 |	  	 	  	|
       |	 |	  		  	+main.yml
       |	 |	  		  
       |	 /webserver/
       | 
       + ...
       		         			  
```

#### 1/ Modules 

These are a where the jobs of the tasks are defined, it's like a method with it's args, return value, exception.... They 
are like library and plugins, Ansible can be extended to get new modules added to the standard ones brought at ansible installation time.
 
To list all available modules, type : 
```
ansible-doc -l
```

If you want documentation about a particular module, for instance **file** module : 

```
ansible-doc file
 > FILE

  Sets attributes of files, symlinks, and directories, or removes files/symlinks/directories. Many other modules support the same options as the [file] module - including [copy], [template],
  and [assemble].

Options (= is mandatory):

- follow
        This flag indicates that filesystem links, if they exist, should be followed.
        (Choices: yes, no)[Default: no]
- force
        force the creation of the symlinks in two cases: the source file does not exist (but will appear later); the destination exists and is a file (so, we need to unlink the "path" file
        and create symlink to the "src" file in place of it).
        (Choices: yes, no)[Default: no]
- group
        name of the group that should own the file/directory, as would be fed to `chown'
        [Default: None]
- mode
        mode the file or directory should be. For those used to `/usr/bin/chmod' remember that modes are actually octal numbers (like 0644). Leaving off the leading zero will likely have
        unexpected results. As of version 1.8, the mode may be specified as a symbolic mode (for example, `u+rwx' or `u=rw,g=r,o=r').
        [Default: None]
- owner
        name of the user that should own the file/directory, as would be fed to `chown'
        [Default: None]
= path
        path to the file being managed.  Aliases: `dest', `name'
        [Default: []]
- recurse
        recursively set the specified file attributes (applies only to state=directory)
        (Choices: yes, no)[Default: no]
- selevel
        level part of the SELinux file context. This is the MLS/MCS attribute, sometimes known as the `range'. `_default' feature works as for `seuser'.
        [Default: s0]
- serole
        role part of SELinux file context, `_default' feature works as for `seuser'.
        [Default: None]
- setype
        type part of SELinux file context, `_default' feature works as for `seuser'.
        [Default: None]
- seuser
        user part of SELinux file context. Will default to system policy, if applicable. If set to `_default', it will use the `user' portion of the policy if available
        [Default: None]
- src
        path of the file to link to (applies only to `state=link'). Will accept absolute, relative and nonexisting paths. Relative paths are not expanded.
        [Default: None]
- state
        If `directory', all immediate subdirectories will be created if they do not exist, since 1.7 they will be created with the supplied permissions. If `file', the file will NOT be
        created if it does not exist, see the [copy] or [template] module if you want that behavior.  If `link', the symbolic link will be created or changed. Use `hard' for hardlinks. If
        `absent', directories will be recursively deleted, and files or symlinks will be unlinked. Note that [file] will not fail if the `path' does not exist as the state did not change. If
        `touch' (new in 1.4), an empty file will be created if the `path' does not exist, while an existing file or directory will receive updated file access and modification times (similar
        to the way `touch` works from the command line).
        (Choices: file, link, directory, hard, touch, absent)[Default: file]
- unsafe_writes
        Normally this module uses atomic operations to prevent data corruption or inconsistent reads from the target files, sometimes systems are configured or just broken in ways that
        prevent this. One example are docker mounted files, they cannot be updated atomically and can only be done in an unsafe manner.
        This boolean option allows ansible to fall back to unsafe methods of updating files for those cases in which you do not have any other choice. Be aware that this is subject to race
        conditions and can lead to data corruption.
        [Default: False]
Notes:
  * See also [copy], [template], [assemble]
EXAMPLES:
# change file ownership, group and mode. When specifying mode using octal numbers, first digit should always be 0.
- file: path=/etc/foo.conf owner=foo group=foo mode=0644
- file: src=/file/to/link/to dest=/path/to/symlink owner=foo group=foo state=link
- file: src=/tmp/{{ item.src }} dest={{ item.dest }} state=link
  with_items:
    - { src: 'x', dest: 'y' }
    - { src: 'z', dest: 'k' }
```

#### 2/ Inventory

The list of hosts and groups that will be targeted by ansible.
[Inventory doc](http://docs.ansible.com/ansible/intro_inventory.html)

for the current examples we defined only one host called "192.168.130.100" in the group windows:
```
[windows]
192.168.130.100
```

#### 3/ Variables

Ansible is designed to be highly parametrable with variables. These variables can be defined at many places, to name:

- the inventory can contains variable definition per host or group
- playbook files can contain variables and explicit include of var files
- if you have a typical directory tree like above, you can store you variable in clever ways using group_vars and
 host_vars directory


### Ansible adhoc mode

In adhoc module, we will use ansible command to perform ponctual module call on our windows host. The command will look
 like: 
 
```
ansible -i inventory HOST_FILTER -m module [-a "MODULE_ARGS"] [OPTS]
```

Where: 
 
 - **inventory** is either the path to the inventory file, either a list of comma separated host
 - **HOST_FILTER** can be 
 	+ ***all*** 			: apply the command on all host defined
 	+ **windows** 			: apply the command on the **windows** group define in inventory
	+ **192.168.130.100** 	: apply the command on the **192.168.130.100** host 
 - **[ -a "MODULE_ARGS"]**  : if calling module with args, add -a and put the module call args "k=v k2=v2 ..."
 - **[OPTS]**				: ansible call options

 
#### Ansible to windows guest connection setup and ping
  
##### 1/ Credentials configg
The module we will use is the most basic of all: **ping**, which only try to establish the connection  to the guest.
Beware: 
- this is NOT AN ICMP ping 
- this try to establish the command connection, which is by default an ssh connection. With our windows guest, 
we will use **win_ping** to make the ping accross winrm connection

To connect to our windows host, **win_ping**  needs to have the following variables loaded before the module:  
- ansible_user:   									# User to be on guest machineg
- ansible_password:   								# user password
- ansible_port: 5986  								# Winrm port
- ansible_connection: winrm  						# winrm connection type 
- ansible_winrm_server_cert_validation: ignore 		# Ignore cert verif, interactive is relou


Theses variable SHOULD be defined in either: 

- group_vars/windows.yml : the variables in these files will be loaded whenever a host in the windows group is targeted in the host
filter

- host_vars/192.168.130.100.yml : the previous variable can be overriden by ansible if they contains the same as the 
default variable loading precedence is group_vars/all.yml >  group_vars/all.yml > host_vars/192.168.130.100.yml 
 
Anyway, typically in web arch deployement, all host running micro service may be created / destructed on the fly according to 
the load the system receives. In this case, it's simple to have the same system user accounts on all the group windows,
 thus we SHOULD place it in group_vars/windows.yml
 
 
##### 2/ Ping the windows host

Once done, we can test the connection to the host 192.168.130.100 which is in the windows groupe host : 

```
ansible -i hosts windows -m win_ping 
```
Outputs:
 ```
192.168.130.100 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

We can ping all machine in host inventory, the variable load mechanism will be able to fetch the winrm connection data 
  because it will load all group_vars/* file:

```
ansible -i hosts all -m win_ping
```
Outputs:
```
192.168.130.100 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

Or we can ping only  192.168.130.100  host: 
```
ansible -i hosts 192.168.130.100 -m win_ping 
```
Outputs: 
```
192.168.130.100 | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

##### 3/ Get informations about our host : 

We will use the setup method will returns information about the targeted hosts :

```
ansible -i hosts windows -m setup 
```
Outputs:
```
 192.168.130.100 | SUCCESS => {
    "ansible_facts": {
        "ansible_architecture": "64-bit", 
        "ansible_bios_date": "11/30/2006", 
        "ansible_bios_version": "VirtualBox", 
        "ansible_date_time": {
            "date": "2017-02-16", 
            "day": "16", 
            "epoch": "1487237515.96161", 
            "hour": "09", 
            "iso8601": "2017-02-16T17:31:55Z", 
            "iso8601_basic": "20170216T093155930422", 
            "iso8601_basic_short": "20170216T093155", 
            "iso8601_micro": "2017-02-16T17:31:55.930422Z", 
            "minute": "31", 
            "month": "02", 
            "second": "55", 
            "time": "09:31:55", 
            "tz": "Pacific Standard Time", 
            "tz_offset": "-08:00", 
            "weekday": "Thursday", 
            "weekday_number": "4", 
            "weeknumber": "6", 
            "year": "2017"
        }, 
        "ansible_distribution": "Microsoft Windows Server 2012 R2 Standard", 
        "ansible_distribution_major_version": "6", 
        "ansible_distribution_version": "6.3.9600.0", 
        "ansible_domain": "", 
        "ansible_env": {
            "ALLUSERSPROFILE": "C:\\ProgramData", 
            "APPDATA": "C:\\Users\\Administrator\\AppData\\Roaming", 
            "COMPUTERNAME": "WINDOWS-GUEST", 
            "ComSpec": "C:\\Windows\\system32\\cmd.exe", 
            "CommonProgramFiles": "C:\\Program Files\\Common Files", 
            "CommonProgramFiles(x86)": "C:\\Program Files (x86)\\Common Files", 
            "CommonProgramW6432": "C:\\Program Files\\Common Files", 
            "FP_NO_HOST_CHECK": "NO", 
            "LOCALAPPDATA": "C:\\Users\\Administrator\\AppData\\Local", 
            "MODULE_COMPLEX_ARGS": "{\"_ansible_version\": \"2.2.1.0\", \"_ansible_selinux_special_fs\": [\"fuse\", \"nfs\", \"vboxsf\", \"ramfs\"], \"_ansible_no_log\": false, \"_ansible_module_name\": \"setup\", \"_ansible_verbosity\": 0, \"_ansible_syslog_facility\": \"LOG_USER\", \"_ansible_diff\": false, \"_ansible_debug\": false, \"_ansible_check_mode\": false}", 
            "NUMBER_OF_PROCESSORS": "2", 
            "OS": "Windows_NT", 
            "PATHEXT": ".COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC;.CPL", 
            "PROCESSOR_ARCHITECTURE": "AMD64", 
            "PROCESSOR_IDENTIFIER": "Intel64 Family 6 Model 60 Stepping 3, GenuineIntel", 
            "PROCESSOR_LEVEL": "6", 
            "PROCESSOR_REVISION": "3c03", 
            "PROMPT": "$P$G", 
            "PSExecutionPolicyPreference": "Unrestricted", 
            "PSModulePath": "C:\\Users\\Administrator\\Documents\\WindowsPowerShell\\Modules;C:\\Program Files\\WindowsPowerShell\\Modules;C:\\Windows\\system32\\WindowsPowerShell\\v1.0\\Modules", 
            "PUBLIC": "C:\\Users\\Public", 
            "Path": "C:\\Windows\\system32;C:\\Windows;C:\\Windows\\System32\\Wbem;C:\\Windows\\System32\\WindowsPowerShell\\v1.0", 
            "ProgramData": "C:\\ProgramData", 
            "ProgramFiles": "C:\\Program Files", 
            "ProgramFiles(x86)": "C:\\Program Files (x86)", 
            "ProgramW6432": "C:\\Program Files", 
            "SystemDrive": "C:", 
            "SystemRoot": "C:\\Windows", 
            "TEMP": "C:\\Users\\ADMINI~1\\AppData\\Local\\Temp", 
            "TMP": "C:\\Users\\ADMINI~1\\AppData\\Local\\Temp", 
            "USERDOMAIN": "WINDOWS-GUEST", 
            "USERNAME": "Administrator", 
            "USERPROFILE": "C:\\Users\\Administrator", 
            "windir": "C:\\Windows"
        }, 
        "ansible_fqdn": "windows-guest.", 
        "ansible_hostname": "WINDOWS-GUEST", 
        "ansible_interfaces": [
            {
                "default_gateway": "10.0.2.2", 
                "dns_domain": "eucleia.corp", 
                "interface_index": 12, 
                "interface_name": "Intel(R) PRO/1000 MT Desktop Adapter"
            }, 
            {
                "default_gateway": null, 
                "dns_domain": null, 
                "interface_index": 15, 
                "interface_name": "Intel(R) PRO/1000 MT Desktop Adapter #2"
            }
        ], 
        "ansible_ip_addresses": [
            "10.0.2.15", 
            "fe80::e488:b85c:5262:ff86", 
            "192.168.130.100", 
            "fe80::172:54cf:d348:cad3"
        ], 
        "ansible_kernel": "6.3.9600.0", 
        "ansible_lastboot": "2017-02-15 05:32:25Z", 
        "ansible_machine_id": "S-1-5-21-3541430928-2051711210-1391384369", 
        "ansible_memtotal_mb": 2048, 
        "ansible_nodename": "windows-guest.", 
        "ansible_os_family": "Windows", 
        "ansible_os_name": "Microsoft Windows Server 2012 R2 Standard", 
        "ansible_owner_contact": "", 
        "ansible_owner_name": "", 
        "ansible_powershell_version": 4, 
        "ansible_processor": [
            "GenuineIntel", 
            "Intel(R) Core(TM) i7-4702HQ CPU @ 2.20GHz", 
            "GenuineIntel", 
            "Intel(R) Core(TM) i7-4702HQ CPU @ 2.20GHz"
        ], 
        "ansible_processor_cores": 2, 
        "ansible_processor_count": 1, 
        "ansible_processor_threads_per_core": 1, 
        "ansible_processor_vcpus": 2, 
        "ansible_product_name": "VirtualBox", 
        "ansible_product_serial": "0", 
        "ansible_reboot_pending": true, 
        "ansible_swaptotal_mb": 0, 
        "ansible_system": "Win32NT", 
        "ansible_system_description": "", 
        "ansible_system_vendor": "innotek GmbH", 
        "ansible_uptime_seconds": 100771, 
        "ansible_user_dir": "C:\\Users\\Administrator", 
        "ansible_user_gecos": "", 
        "ansible_user_id": "Administrator", 
        "ansible_user_sid": "S-1-5-21-3541430928-2051711210-1391384369-500", 
        "ansible_win_rm_certificate_expires": "2018-02-12 23:01:45", 
        "ansible_windows_domain": "WORKGROUP", 
        "module_setup": true
    }, 
    "changed": false
}

```


#### Miscellaneous adhoc task example - a little discovery

##### 1/ Copy a file: win_copy module

To copy a file on all windows group hosts, use the win_copy module :  
```
ansible -i hosts windows -m win_copy -a "src=./files/youhou.txt dest=C:/Users/Administrator/Desktop/youhou" 
192.168.130.100 | SUCCESS => {
    "changed": true, 
    "checksum": "8952089e37a24bf761ce8fc0122319f9b4f72c3f", 
    "operation": "file_copy", 
    "original_basename": "youhou.txt", 
    "size": 16
}
```

##### 2/ Send a templated file: win_template

Here the variable value is given as an extra args. More about setting template variables in playbook chapter

```
ansible -i hosts windows -m win_template -a "src=./files/index.html.j2 dest=C:/Users/Administrator/Desktop/index.html" 
-e hello_msg=toto
192.168.130.100 | SUCCESS => {
    "changed": true, 
    "operation": "file_copy", 
    "original_basename": "index.html.j2", 
    "size": 333
}
```

##### 3/ Execute a powershell script:


With this method, the script is executed from a localfile, lines of the script are pushed to the remote host to be exeted.  
```
ansible -i hosts windows -m script  -a "files/Hello.ps1 -a b --clong d"
192.168.130.100 | SUCCESS => {
    "changed": true, 
    "operation": "file_copy", 
    "original_basename": "index.html.j2", 
    "size": 333
}
```

We can also push a script, and then use win_shell module to execute a script that resides on the host:

```
ansible -i hosts windows -m win_copy  -a "src=files/Hello.ps1  dest=C:/Users/Administrator/Desktop/Hello.ps1" 
ansible -i hosts windows -m win_shell -a "C:/Users/Administrator/Desktop/Hello.ps1 -a b --clong d chdir=C:/Users/Administrator/"
``` 

### Ansible playbook mode

Adhoc is great to test single module and send commands ponctually. The power of ansible is to give the ability to 
 describe deployement recipes into playbooks. These playbook describes a series of tasks that will be run in order
   as they are described in a .yml playbook file.

To execute a playbook you just need to run the ansible-playbook command:

```
ansible-playbook -i hosts ping.yml 
``` 

You can add more verbosity to have debug output by adding **-v**, **-vv...** to the args of the command.
 
 
### 1/ Playbook content:

#### Basic structure:

Here is the basic structure of a playbook, it must contains at least a hosts field telling the HOST_FILTER like with the adhoc
mode. It although must contains at least a list of tasks or an include to a role. You SHOULD by the way give a field "name" to 
 your playbook
 

```
	---
	- name: "Reboot hosts"
	  hosts: windows
	  tasks:
		- win_reboot:
				msg: "Test reboot" 
```

The "---" should be placed at the beginning of all the tasks 
 
 
#### Writing tasks:
 
 
To write a task, you just have to put a module name and eventually it's args. You SHOULD give tasks a name.
The args can be YML formatted by listing them in indented mode, or can be set  in the line of the module in a args=val form  

```	
	- name: "Reboot hosts"	  
	  tasks:
		- win_reboot:
				msg: "Test reboot" 
```
Or: 
```	
	- name: "Reboot hosts"	  
	  tasks:
		- win_reboot: msg="Test reboot" 
```
Tasks args can use templates: 
```	
	- name: "Reboot hosts"	  
	  tasks:
		- win_reboot: msg="Test reboot  {{ reboot_msg}}" 
```
 
Tasks can be iterated over a list, dict... see [ansible loops]() 
```	
	- name: "Reboot hosts"	  
	  tasks:
		- template: src="files/msg.html.j2" dest="C:/Users/Admin/Site/index{{ item }}.html' 
			with_items:
				- "I"
				- "am"
				- "the"
				- "Law"
```

Tasks definition file can be included, and you can call this tasks whenever you want in other file by using it's name in further 
files.
 
 
 
***
 
  
#### 1/ Execute script shell in a playbook 

The basic playbook example  [ansible/execute_powershell.yml](ansible/execute_powershell.yml) executes the shell script
  on all the windows hosts.

```
ansible-playbook -vvv  -i hosts  execute_powershell.yml
```

 
 
 
#### 2/ Webserver playbook:

The goal of the playbook here is to setup a website on an IIS server. Basically, the steps invovled are:
- enabling IIS features on the server
- start the IIS  server 
- create a website on IIS
- deploy it's config 

For this example, we will use the implicit includes of all main.yml files and we will not discuss the manual  include
mechanism. So what do we have to do now? Just feed the tasks in main.yml files, set the variables for the role configuration
and  configure all handlers. Handlers are like tasks, but there are called with "notify" keyword which trigs the action once the tasks is done.
 
* Create the tasks:

We will have to edit the tasks/main.yml file to add the tasks. First of all, we will use the win_feature module to set up IIS.





 
 
 
 







 



