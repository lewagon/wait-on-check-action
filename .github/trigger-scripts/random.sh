RANGE=500
number=$RANDOM
let "number %= $RANGE"
ret="`echo $number % 10 | bc`"
echo "$ret"
echo "Random number less than $RANGE  ---  $number"
