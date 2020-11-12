#!/bin/bash
export TOP_PID=$$

input="$1"
output="$2"
extension=($3)
exec=($4)

killer () {
   echo exit from function "${FUNCNAME[ 1 ]}" >&2
   exit 1 
   kill  $TOP_PID
}


select_dir () {
  if [  -z "$input" ]
        then
	clear
	echo 
	echo
	echo "*****************************************************"
	echo "*Select the media directory that contains the files *"
	echo "*****************************************************" 
	read -p "PRESS ENTER TO CONTINUE"
	input="$(zenity --file-selection --directory)"
        if [  -z "$input" ]
                then
			clear 
	                echo "********************************************"  
			echo "*Select a directory that you want to backup*"
 	                echo "********************************************"  
                	$(killer)
        fi
  fi 
  if [  -z "$output" ]
        then
	clear
	echo
	echo
	echo "****************************************************"  
	echo "*Select the media directory where to copy the files*"
	echo "****************************************************"
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


type_extension () {
  if [ -z "$extension" ]
     then
	echo "Type the file extension you want to backup or leave blank for autodiscovery"
	read -a  extension 
    fi
}





copy_or_move () {
  if [ -z "$exec" ]
     then
	exec=(cp copied)
        clear
        echo -e "\n\n"
        read -p "DO you want to move file instead of copy ? yes/no    " ans
        if [ "$ans" == "yes" ]
                then
                        exec=(mv moved)
        fi
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
                if [[ -z "$find_extension"  ]]
	                then   echo "one or more variables are undefined in funcion $FUNCNAME"
			exit 1
                        $(killer)
                fi

	cmd=(dialog --separate-output --checklist "Select filetype you want to backup:" 22  76 16)
	options=( $(echo "$find_extension" | while read num ext ; do  if [[ ! -z "$num" && ! -z "$ext" ]] ; then echo "$ext" "$num" "off" ; fi ;  done))
	extension=($("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty))

                if [[ -z "$extension"  ]]
                        then   echo "one or more variables are undefined in funcion $FUNCNAME"
			exit 1 
                        $(killer)
                fi
}



find_files() {
	first=(${extension[0]})
        if [[ -z "$first"  ]]
        	then   echo "one or more variables are undefined in funcion $FUNCNAME"
        	$(killer)
        fi
	for i in "${extension[@]:1}"
		do
		filter=$( echo $filter -o -name \*.$i)
 	done
	files="$(find "$input"  -type f -name \*.$first $filter)"
}

sort_dir() {
        for i in "${extension[@]}"
		do 
			echo "$files" | grep ".$i" | rev | cut -d "/" -f2- | rev | sort | uniq -c | sort -n |
			while read num path 
				do 
					#path="$(echo "$path" | sed 's/ />/g')"
					echo ["$i"] "$num" "$path" 
			done 
		done 
}		

menu_dir() {
        options=()
        cmd=(dialog --separate-output --checklist "Select dir you want to exlude:" 100  200 100)
        while read ext num path 
		do 
				options+=("$num-$path")
				options+=("$ext")
				options+=('off')
		done <<< `sort_dir` 

        dir=("$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)")
        for i in  "${dir[@]}"
		do echo "$i" | cut -d "-" -f2- 
	done | sort | uniq 
}


dir_filter() {
	menu_dir="$(menu_dir)"
	if [ ! -z "$menu_dir" ]
		then 
			while read i 
				do     
					filter_dir+=("-e")
					filter_dir+=("$i")
					done <<< "$menu_dir"
       					files="$(echo "$files" | grep -v "${filter_dir[@]}")"
	fi
}

copy_files () {
	clear
	while read i
	do      
                if [ -z "$i" ] 
			then echo "files are not defined in funcion $FUNCNAME"
			$(killer)
			exit 1
 		fi
                date="$(date +%Y-%m -r "$i")"
                if [ -z "$date" ]
                        then echo "date is not defined in funcion $FUNCNAME" 
                        $(killer)
			exit 1 
                fi

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
 	done <<< "$files" 
}

warning() {
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
type_extension

	if [ -z "$extension" ] ;
		then
			
			find_extension        
			menu
		fi
find_files
dir_filter
copy_files
warning
