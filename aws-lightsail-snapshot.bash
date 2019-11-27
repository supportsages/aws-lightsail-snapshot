#!/bin/bash


# Take Lightsail snapshot using Cli
# Version: 20191118
# Author: Gerald L, Seff P


# Variables
g_aws_access_key_id=ACCESSXXXXXXXXXXXXKEY
g_aws_secret_access_key=SECRETXXXXXXXXXXXXXXXXXXXXXXXXKEY
ret_count_default=1
t="true"
f="false"


tab() {
	for i in $(seq $1)
		do echo -ne "\t"
	done
}

init()
{
	echo "Preparing for backup"
	export AWS_ACCESS_KEY_ID=$g_aws_access_key_id
	export AWS_SECRET_ACCESS_KEY=$g_aws_secret_access_key
	export AWS_DEFAULT_REGION=ap-south-1
	export AWS_DEFAULT_OUTPUT=table
}

main()
{
        echo -e "\nFinding the instances at $reg"
	for i_name in $(aws lightsail get-instances | grep -i -A13 instances | grep -w name | awk '{print $4}')
        do
                        echo -e "\n$(tab 1)Checking if backup is enabled for $i_name..."
			i_details=$(aws lightsail get-instance --instance-name $i_name)
			s_enable=$(echo "$i_details" | awk '/backup.enable/ {print $4}')
			if [[ "$t" != "$s_enable" && "$f" != "$s_enable" ]];
			then
				echo "$(tab 2)Backup status for $i_name is undefined"
			elif [ "$f" == "$s_enable" ];
			then
				echo "$(tab 2)Backups are disabled for $i_name "
			elif [ "$t" == "$(aws lightsail get-instance --instance-name $i_name | awk '/backup.enable/ {print $4}')" ]
			then
				echo "$(tab 2)Backups are enabled for $i_name"
				ret_count=$(echo "$i_details" | awk '/backup.retention/ {print $4}' | grep "^[0-9]*$")
				if [ -z "$ret_count" ]
					then echo "$(tab 2)Backup retention not specified. Set to default value $ret_count_default"
					ret_count=$ret_count_default
				else
					echo "$(tab 2)Backup retention is $ret_count"
				fi
				s_name=snapof-$i_name-$(date +%Y%m%d_%H%M)
				echo "$(tab 2)Initiating snapshot $s_name.."
				aws lightsail create-instance-snapshot --instance-snapshot-name $s_name --instance-name $i_name
				if [ $(aws lightsail get-instance-snapshots | grep name | awk '{print $4}' | grep -c $i_name ) -gt $ret_count ]
				then
					echo "$(tab 2)More than $ret_count backups are available for $i_name"
					for s_name in $(aws lightsail get-instance-snapshots | grep name | awk '{print $4}' | grep "snapof-$i_name" | sort)
					do
						echo "$(tab 3) Deleting backup $s_name"
						aws lightsail delete-instance-snapshot --instance-snapshot-name $s_name	
						if [ $(aws lightsail get-instance-snapshots | grep name | awk '{print $4}' | grep -c $i_name) -eq $ret_count ]
						then
							echo "$(tab 3)Exiting as only $ret_count backup(s) are available now."
							break
						fi
					done
				fi
			fi
        done
}


init
for reg in $(aws lightsail get-regions | grep name | awk '{print $4}')
do
        export AWS_DEFAULT_REGION=$reg
	main
done
