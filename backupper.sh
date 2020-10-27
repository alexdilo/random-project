#!/bin/bash
export TOP_PID=$$

input="$1"
output="$2"

killer () {
   echo exit from function "${FUNCNAME[ 1 ]}" >&2
   kill -9 $TOP_PID
}


select_dir () {
  if [  -z "$input" ]
        then
	clear
	echo 
	echo
	echo "*****************************************************"
	echo "*Select the media directory that contains the fileis*"
	echo "*****************************************************" 
	read -p "PRESS ENTER TO CONTINUE"
	input="$(zenity --file-selection --directory)"
        if [  -z "$input" ]
                then
			clear 
	                echo "***************************************************"  
			echo "*please select a directory that you want to backup*"
 	                echo "***************************************************"  
                	$(killer)
        fi
  fi 
  if [  -z "$output" ]
        then
	clear
	echo
	echo
	echo "*********************************************************"  
	echo "*Select the media directory where to copy the files*"
	echo "*********************************************************"
	read -p "PRESS ENTER TO CONTINUE"
	output="$(zenity --file-selection --directory)"
        if [  -z "$output" ]
                then
			clear 
			echo "**********************************************************************"  
			echo "*WARNING:Please select a directory where you want to save your backup*"
                	echo "**********************************************************************"  
                	$(killer)
        fi
	clear
fi
}

copy_or_move () {
        exec=(cp copied)
	clear 
	echo -e "\n\n"
	read -p "DO you want to move file instead of copy ? yes/no    " ans
	if [ "$ans" == "yes" ] 
		then
			exec=(mv moved)
	fi
}


delete_cache () {
        if [ -f "/tmp/ignored_files" ]
                then
                        rm /tmp/ignored_files
        fi
	if [ -f "/tmp/failed" ]
                then
                        rm /tmp/failed
        fi

}


check_dialog () {
	if ! which dialog &> /dev/null ; then
    		echo "you need to install dialog"
		exit 
	fi
}


check_dir () {
	if [ ! -d "$input" ]
 		then echo "the directory $input doesn't exist"
                $(killer)
	fi
	if [ ! "$(ls -A "$input")" ] 
  		then echo "the directory $input is empty"
                $(killer)
	fi
        if [  -z "$output" ]
                then echo "please specify the output directory"
                $(killer)
        fi 
}



find_extension () {
	find_extension=$(find "$input" -type f | rev |  cut -d "/" -f1 | cut -s -d "." -f1 | rev | sort | grep -v ' ' | grep -v '[^a-zA-Z0-9 \t]' |  uniq -c | sort -n)
}

date_from_name () {
        date_lower_limt="2000"
 	upperlimit=$(date +%G)
	date_from_name="$(echo "$1" | grep -Po "(19|20)\d\d(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])" | sed 's/\(....\)\(..\)/\1-\2-/' | cut -d "-" -f1,2)"
	yyyy="$(echo $date_from_name | cut -d '-' -f1)"
	if [ ! -z  "$yyyy" ] ; then 
	        if ! ((  "$yyyy" >= "$date_lower_limt"  && "$yyyy" <= "$upperlimit" )); then
			date_from_name=''
		fi
	fi
}

menu () {
	cmd=(dialog --separate-output --checklist "Select filetype you want to backup:" 22  76 16)
	options=( $(echo "$find_extension" | while read num ext ; do echo "$ext" "$num" "off" ; done))
	extension=($("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty))
                if [[ -z "$extension"  ]]
                        then   echo 'please select one o more extension, a variables is undefined'
                        $(killer)
                fi
}



find_files() {
	first=(${extension[0]})
	filter=$(echo -name *.$first)
        if [[ -z "$first" ||  -z "$filter" ]]
        	then   echo 'one or more variables are undefined'
        	$(killer)
        fi
	for i in "${extension[@]:1}"
		do
		filter=$( echo $filter -o -name *.$i)
 	done
	files="$(find "$input"  -type f $filter)"
}

copy_files () {
	echo "$files" | while read i
	do      
                if [ -z "$i" ] 
			then "files are not defined in funcion $FUNCNAME" 
			$(killer)
 		fi
                date="$(date +%Y-%m -r "$i")"
		date_from_name "$i"
		if [ ! -z "$date_from_name" ]
                        then
                                date="$date_from_name"
                fi
 		extension="$(echo $i | rev | cut -d "/" -f1 | cut -s -d "." -f1 | rev)"
 		filename="$(echo $i | rev | cut -d "/" -f1 | rev)"
		path="$output/$date/$extension"
		if [[ -z "$path" ||  -z "$date" || -z "$extension" || -z "$filename" ]]
			then   echo "one or more variables are undefined $i" 
                        continue
 		fi
		
		if [ -f "$path/$filename" ] 
			then	
				new=$(md5sum "$i" | awk '{print $1}')
				old=$(md5sum "$path/$filename" |  awk '{print $1}')
 				if  [ "$new" == "$old" ]
					then
						echo "the file $i already exist $path/$filename "
						if [ "$ans" == "yes" ]
							then	
								if [ ! "$i" == "$path/$filename" ]
									then
										rm "$i"
										echo "file $i removed"
								fi
						fi
         					continue
					else
						echo "IGNORING COPY: the files $i and $path/$filename are different" >> /tmp/ignored_files
				fi 

        	fi
  		
 		mkdir -p "$path" || { echo "directory creation $path has failed" ; exit 1; }
		${exec[0]} -n "$i" "$path/$filename" && echo "file $i ${exec[1]} $path/$filename"  || { echo "copy file $i to "$path/$filename" has failed" 2>&1 >> /tmp/failed ;  }
 	done

    	if [ -f "/tmp/ignored_files" ]
		then
		        echo
        		echo
        		echo                         WARNING
        		echo  
			cat /tmp/ignored_files
			rm /tmp/ignored_files
        fi

        if [ -f "/tmp/failed" ]
                then
                        echo
                        echo
                        echo                         WARNING
                        echo  
                        cat /tmp/failed
                        rm /tmp/failed
        fi

}

check_dialog
select_dir
check_dir
copy_or_move
delete_cache
find_extension        
menu
find_files
copy_files
