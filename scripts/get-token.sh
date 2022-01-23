#! /bin/sh

requestRemoteAddr=$(echo $1 | cut -d: -f1)
tokenListFilePath="/tmp/tokenList.txt"

touch $tokenListFilePath

while IFS="=" read -r remoteAddr token
do
    if [ "$remoteAddr" = "$requestRemoteAddr" ]
    then
        echo $token
        exit 0
    fi
done < $tokenListFilePath

authToken=$(cat /proc/sys/kernel/random/uuid | sed 's/[-]//g' | head -c 20; echo;)

echo "$requestRemoteAddr=$authToken" >> "$tokenListFilePath"

echo $authToken
exit 0

