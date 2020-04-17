#!/bin/bash
input=$1
output=$2

export TOP_PID=$$
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
	find_extension=$(find "$input" -type f | rev |  cut -d "/" -f1 | cut -s -d "." -f1 | rev | sort | uniq -c | sort -n)
}

date_from_name () {
echo $1 | grep -Po "(19|20)\d\d(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])" | sed 's/\(....\)\(..\)/\1-\2-/' | cut -d "-" -f1,2 
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
		date_from_name="$(date_from_name "$i")"
		 if [ ! -z "$date_from_name" ]
                        then
                                date="$date_from_name"
                fi
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
				old=$(md5sum "$path/$filename" |  awk '{print $1}')
 				if  [ "$new" == "$old" ]
					then
						echo "the file $i already exist $path/$filename "
        					continue
					else
						echo "IGNORING COPY: the files $i and $path/$filename are different" >> /tmp/ignored_files
				fi 

        	fi
  		
 		mkdir -p "$path" || { echo "directory creation $path has failed" ; exit 1; }
		cp -n "$i" "$path/$filename" && echo "file $i copied $path/$filename"  || { echo "copy file $i to "$path/$filename" has failed" 2>&1 >> /tmp/failed ;  }
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
check_dir
delete_cache
find_extension        
menu
find_files
copy_files
