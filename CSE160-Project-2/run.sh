#!/bin/bash  

echo "Going into Lab"  
cd Lab
echo "I am done running ls" 
make micaz sim
python neighborTest.py
 
echo ""
