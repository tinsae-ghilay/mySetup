#!/bin/bash


echo "yes or no"
read response

if [ "$response = y" || "$response = Y" ]; then
	echo "answered yes"
else
	echo "answered who cares"
fi

