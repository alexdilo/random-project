#!/bin/bash
input=$1
output=$2

export TOP_PID=$$
delete_cache () {
        if [ -f "/tmp/ignored_files" ]
                then
                        rm /tmp/ignored_files
        fi
}

killer () {
   echo exit from function "${FUNCNAME[ 1 ]}"  
   kill -9 $TOP_PID
}

check_dialog () {
	if ! which dialog &> /dev/null ; then
    		echo "you need to install dialog"
		exit 
	fi
}


check_dir () {
	if [ ! -d "$input" ]
 		then echo "the directory $1 doesn't exist"
                $(killer)
	fi
	if [ ! "$(ls -A $input)" ] 
  		then echo "the directory $1 is empty"
                $(killer)
	fi 
}



find_extension () {
	find_extension=$(find "$input" -type f | rev |  cut -d "/" -f1 | cut -s -d "." -f1 | rev | sort | uniq -c | sort -n)
}


menu () {
	cmd=(dialog --separate-output --checklist "Select filetype you wnat to backup:" 22  76 16)
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
 		extension="$(echo $i | rev | cut -d "/" -f1 | cut -s -d "." -f1 | rev)"
 		filename="$(echo $i | rev | cut -d "/" -f1 | rev)"
		path="$output/$date/$extension"
		
		if [[ -z "$path" ||  -z "$date" || -z "$extension" || -z "$filename" ]]
			then   echo 'one or more variables are undefined' 
                        $(killer)
 		fi
		
		if [ -f "$path/$filename" ] 
			then	
				new=$(md5sum "$i" | awk '{print $1}')
				old=$(md5sum $path/$filename |  awk '{print $1}')
 				if  [ $new == $old ]
					then
						echo "the file $i already exist $path/$filename "
        					continue
					else
						echo "IGNORING COPY: the files $i and $path/$filename are different" >> /tmp/ignored_files
				fi 

        	fi
  		
 		mkdir -p "$path" || { echo "directory creation $path has failed" ; exit 1; }
		cp -n "$i" "$path/$filename"  || { echo "copy file $i to "$path/$filename" has failed" ; $(killer); }
        done
        echo
        echo                         WARNING
        echo 
    	if [ -f "/tmp/ignored_files" ]
		then 
			cat /tmp/ignored_files
			rm /tmp/ignored_files
        fi

}

check_dialog
check_dir
delete_cache
find_extension        
menu
find_files
copy_files
 
#copy_files   
# new=$(md5sum "$i" | awk '{print $1}')
# old=$(md5sum $output/$date/$filename)
