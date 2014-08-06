#!/bin/bash

pass=$*
echo -n $pass | while read -n 1 c
do 
[[ "$c" == [!@#$%^&*().] ]] && echo -n "\\"
echo -n $c
done