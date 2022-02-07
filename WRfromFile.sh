#!/bin/bash
#This is a script to write/read file data 

declare -A tmp_list
declare -A sen_ver4

#sen_ver1=()


i=0; j=0

ListCopy(){
	declare -A a
	#sen_ver4=()
	a=$1
	a=()
	let i+=-1
	let j+=-1
	for ii in $(seq 0 $i); do
		for jj in $(seq 0 $j); do
		       a[$ii,$jj]=${tmp_list[$ii,$jj]}
		       echo "hi  " $ii $jj ${a[$ii,$jj]}
       	       done
 	done
	echo "dd 00 "${a[0,0]}
	echo "dd 01 "${a[0,1]}
	echo "dd 10 "${a[1,0]}
	echo "dd 11 "${a[1,1]}
	echo "dd 20 "${a[2,0]}
	
}

ReadFile() {
	tmp_list=()
	readFlag=0; i=0; j=0
	while IFS=" " read -r line; do
		if [[ "$line" == *"ITEM"* ]] && [[ "$line" == *"$1"* ]] && [[ "$line" == *"enable"* ]] && [[ $readFlag == 0 ]]; then
			readFlag=1
			continue
			
		
		elif [[ $line ]] && [[ $readFlag = 1 ]] ; then
			j=0
			for ele in $line; do
		       		tmp_list[$i,$j]=$ele
		       		echo $i $j ${tmp_list[$i,$j]}
		       		let j+=1
        		done
			let i+=1

		elif [[ !$line ]] && [[ $readFlag = 1 ]]; then
			break
		fi
			
	done < ./config/TEST_config.txt
}

config_init(){
	ReadFile ver4
	#ListCopy "${sen_ver4[*]}"
	echo "tmp = "${tmp_list[0,0]}
	#echo "sen_ver4 = "${sen_ver4[0,0]}

	ReadFile ver1
	#ListCopy
	echo "tmp = "${tmp_list[0,0]}

}

config_init

echo "[0 0] = "${sen_ver1[0,0]}



exit 0
